import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

import { CAREGIVER_CONSENT_DEFAULT_TTL_MS } from "@/lib/consent/consent-token-ttl";
import {
  issueServerCaregiverConsentToken,
  verifyServerCaregiverConsentToken,
} from "@/lib/server/caregiver-consent-crypto";
import { issueServerCoachConsentToken } from "@/lib/server/coach-consent-crypto";
import { handleCaregiverConsentRenewal } from "@/lib/server/consent-renewal-handler";
import { handleConsentRevocation } from "@/lib/server/consent-revoke-handler";
import {
  ConsentGrantNotRenewableError,
  recordConsentGrantIssued,
  setConsentRevocationBackendForTest,
  type ConsentGrantRecord,
  type ConsentRevocationBackend,
} from "@/lib/server/consent-revocation-store";
import type { CaregiverPermissions, MonitoringConsentToken } from "@/types/caregiver";
import type { CoachSharingPermissions } from "@/types/coach-client-relationship";

/**
 * Behavioural suite for owner-confirmed caregiver consent renewal.
 *
 * The properties worth stating plainly, because each is a way the feature
 * could quietly become the thing it was built to avoid:
 *
 * - the caregiver cannot renew the grant they hold, so a 7-day credential
 *   cannot extend its own life;
 * - the predecessor stops verifying the moment a successor exists, so a
 *   renewal cannot leave two working credentials behind;
 * - an interrupted renewal leaves at most one live credential, and prefers to
 *   leave the predecessor alone rather than half-install a successor;
 * - an unreadable revocation list denies the renewal, matching what `verify`
 *   already does with the same uncertainty.
 */

const CAREGIVER_PERMISSIONS: CaregiverPermissions = {
  evidenceStreamIds: ["mood"],
  reviewSummaries: true,
  thresholdAlerts: false,
};

const COACH_PERMISSIONS: CoachSharingPermissions = {
  factLedger: false,
  confidenceBandedInsights: true,
  insightKinds: ["belief"],
};

const OWNER = "owner-account-1";
const CAREGIVER = "caregiver-account-1";
const COACH = "coach-account-1";

/** A backend whose every operation fails, standing in for a store outage. */
function outageBackend(message = "connection refused"): ConsentRevocationBackend {
  const fail = async (): Promise<never> => {
    throw new Error(message);
  };
  return {
    name: "outage",
    read: fail,
    upsertGrant: fail,
    revoke: fail,
    renew: fail,
  };
}

interface InspectableBackend extends ConsentRevocationBackend {
  /** Grant ids with no withdrawal recorded — the credentials still in play. */
  liveGrantIds(): string[];
}

function toRecord(
  input: {
    tokenId: string;
    grantKind: ConsentGrantRecord["grantKind"];
    subjectAccountId: string;
    partyId: string;
    relationshipId?: string | null;
    issuedAt?: string | null;
    expiresAt?: string | null;
  },
  revocation: Pick<
    ConsentGrantRecord,
    "revokedAt" | "revokedBy" | "revocationReason"
  >,
): ConsentGrantRecord {
  return {
    tokenId: input.tokenId,
    grantKind: input.grantKind,
    subjectAccountId: input.subjectAccountId,
    partyId: input.partyId,
    relationshipId: input.relationshipId ?? null,
    issuedAt: input.issuedAt ?? null,
    expiresAt: input.expiresAt ?? null,
    permissions: CAREGIVER_PERMISSIONS,
    ...revocation,
  };
}

/**
 * In-memory store whose `renew` commits through a staged copy, mirroring what
 * a transaction gives the Postgres backend: the two halves become visible
 * together or not at all.
 *
 * `interruptBeforeCommit` drops the process between staging and committing,
 * which is the crash this design exists to survive.
 */
function memoryBackend(
  options: { interruptBeforeCommit?: boolean } = {},
): InspectableBackend {
  const rows = new Map<string, ConsentGrantRecord>();

  return {
    name: "memory",

    liveGrantIds() {
      return [...rows.values()]
        .filter((row) => row.revokedAt == null)
        .map((row) => row.tokenId);
    },

    async read(tokenId) {
      return rows.get(tokenId) ?? null;
    },

    async upsertGrant(input) {
      const existing = rows.get(input.tokenId);
      rows.set(
        input.tokenId,
        toRecord(input, {
          revokedAt: existing?.revokedAt ?? null,
          revokedBy: existing?.revokedBy ?? null,
          revocationReason: existing?.revocationReason ?? null,
        }),
      );
    },

    async revoke(input) {
      const existing = rows.get(input.tokenId);
      if (existing?.revokedAt) {
        return {
          tokenId: input.tokenId,
          revokedAt: existing.revokedAt,
          alreadyRevoked: true,
        };
      }
      const revokedAt = (input.now ?? new Date()).toISOString();
      rows.set(
        input.tokenId,
        toRecord(
          {
            tokenId: input.tokenId,
            grantKind: existing?.grantKind ?? input.grantKind,
            subjectAccountId:
              existing?.subjectAccountId ?? input.subjectAccountId,
            partyId: existing?.partyId ?? input.partyId,
            relationshipId:
              existing?.relationshipId ?? input.relationshipId ?? null,
            issuedAt: existing?.issuedAt ?? input.issuedAt ?? null,
            expiresAt: existing?.expiresAt ?? input.expiresAt ?? null,
          },
          {
            revokedAt,
            revokedBy: input.revokedBy,
            revocationReason: input.revocationReason ?? null,
          },
        ),
      );
      return { tokenId: input.tokenId, revokedAt, alreadyRevoked: false };
    },

    async renew(input) {
      const staged = new Map(rows);
      const previous = staged.get(input.previousTokenId);
      if (previous?.revokedAt) {
        throw new ConsentGrantNotRenewableError("previous_grant_revoked");
      }

      const revokedAt = (input.now ?? new Date()).toISOString();
      staged.set(
        input.previousTokenId,
        toRecord(
          {
            tokenId: input.previousTokenId,
            grantKind: previous?.grantKind ?? input.replacement.grantKind,
            subjectAccountId:
              previous?.subjectAccountId ?? input.replacement.subjectAccountId,
            partyId: previous?.partyId ?? input.replacement.partyId,
            relationshipId: previous?.relationshipId ?? null,
            issuedAt: previous?.issuedAt ?? input.previousIssuedAt ?? null,
            expiresAt: previous?.expiresAt ?? input.previousExpiresAt ?? null,
          },
          {
            revokedAt,
            revokedBy: input.revokedBy,
            revocationReason: input.revocationReason ?? null,
          },
        ),
      );
      staged.set(
        input.replacement.tokenId,
        toRecord(input.replacement, {
          revokedAt: null,
          revokedBy: null,
          revocationReason: null,
        }),
      );

      if (options.interruptBeforeCommit) {
        throw new Error("simulated crash before the renewal was committed");
      }

      rows.clear();
      for (const [key, value] of staged) rows.set(key, value);

      return {
        previousTokenId: input.previousTokenId,
        previousRevokedAt: revokedAt,
        newTokenId: input.replacement.tokenId,
      };
    },
  };
}

/**
 * The ordering this design rejects: register the successor, then withdraw the
 * predecessor, as two separate writes.
 *
 * Kept as a test fixture so the "at most one live credential" assertion has
 * something it demonstrably catches. Interrupted between the writes it leaves
 * two working credentials for one arrangement, which is the outcome the real
 * backends are shaped to make impossible.
 */
function nonAtomicBackend(
  options: { interruptBetweenWrites?: boolean } = {},
): InspectableBackend {
  const base = memoryBackend();
  return {
    ...base,
    name: "non-atomic",
    async renew(input) {
      await base.upsertGrant(input.replacement);
      if (options.interruptBetweenWrites) {
        throw new Error("simulated crash between issue and revoke");
      }
      const revoked = await base.revoke({
        tokenId: input.previousTokenId,
        grantKind: input.replacement.grantKind,
        subjectAccountId: input.replacement.subjectAccountId,
        partyId: input.replacement.partyId,
        revokedBy: input.revokedBy,
        revocationReason: input.revocationReason ?? null,
        now: input.now,
      });
      return {
        previousTokenId: input.previousTokenId,
        previousRevokedAt: revoked.revokedAt,
        newTokenId: input.replacement.tokenId,
      };
    },
  };
}

/** A backend that cannot do the swap in one step, so it does not offer one. */
function renewalUnsupportedBackend(): InspectableBackend {
  const base = memoryBackend();
  const { renew: _unsupported, ...withoutRenew } = base;
  return { ...withoutRenew, name: "renewal-unsupported" };
}

function ownerConfirmation(tokenId: string, at: Date = new Date()) {
  return { confirmedTokenId: tokenId, acknowledgedAt: at.toISOString() };
}

async function issueRegisteredCaregiverGrant(options: {
  ttlMs?: number;
  now?: Date;
} = {}): Promise<MonitoringConsentToken> {
  const token = await issueServerCaregiverConsentToken({
    tokenId: randomUUID(),
    subjectAccountId: OWNER,
    caregiverId: CAREGIVER,
    permissions: CAREGIVER_PERMISSIONS,
    ttlMs: options.ttlMs,
    now: options.now,
  });
  await recordConsentGrantIssued({
    tokenId: token.tokenId,
    grantKind: "caregiverMonitoring",
    subjectAccountId: OWNER,
    partyId: CAREGIVER,
    issuedAt: token.issuedAt,
    expiresAt: token.expiresAt,
  });
  return token;
}

export async function runConsentRenewalTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(
        `${name}: ${error instanceof Error ? error.message : String(error)}`,
      );
    } finally {
      setConsentRevocationBackendForTest(null);
    }
  }

  // --- the property the whole endpoint exists to hold ----------------------

  await check("a caregiver cannot renew the grant they hold", async () => {
    const backend = memoryBackend();
    setConsentRevocationBackendForTest(backend);
    const token = await issueRegisteredCaregiverGrant();

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: CAREGIVER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });

    assert.equal(result.ok, false, "the token's holder must not extend it");
    assert.equal(result.ok === false && result.code, "FORBIDDEN");
    assert.deepEqual(
      backend.liveGrantIds(),
      [token.tokenId],
      "a refused renewal must not mint a successor",
    );
    assert.equal(
      (await verifyServerCaregiverConsentToken(token)).valid,
      true,
      "a refused renewal must leave the grant exactly as it was",
    );
  });

  await check("an unrelated account cannot renew someone else's grant", async () => {
    const backend = memoryBackend();
    setConsentRevocationBackendForTest(backend);
    const token = await issueRegisteredCaregiverGrant();

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: "stranger-account",
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });

    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "FORBIDDEN");
    assert.equal(backend.liveGrantIds().length, 1);
  });

  await check("a forged token does not make the forger the owner", async () => {
    const backend = memoryBackend();
    setConsentRevocationBackendForTest(backend);
    const token = await issueRegisteredCaregiverGrant();
    const forged = { ...token, subjectAccountId: "stranger-account" };

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: "stranger-account",
      body: {
        tokenId: token.tokenId,
        token: forged,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });

    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "FORBIDDEN");
    assert.deepEqual(backend.liveGrantIds(), [token.tokenId]);
  });

  // --- the successor replaces the predecessor, rather than joining it ------

  await check("the owner renews, and the previous token stops working", async () => {
    const backend = memoryBackend();
    setConsentRevocationBackendForTest(backend);
    const token = await issueRegisteredCaregiverGrant();
    assert.equal((await verifyServerCaregiverConsentToken(token)).valid, true);

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });

    assert.equal(result.ok, true, result.ok === false ? result.code : "");
    if (!result.ok) return;

    assert.notEqual(
      result.token.tokenId,
      token.tokenId,
      "renewal issues a new identifier, it does not re-date the old one",
    );

    const successor = await verifyServerCaregiverConsentToken(result.token);
    assert.equal(successor.valid, true, successor.reason ?? "no reason given");

    const predecessor = await verifyServerCaregiverConsentToken(token);
    assert.equal(
      predecessor.valid,
      false,
      "the replaced token must stop verifying — a renewal that leaves it live is the failure this exists to prevent",
    );
    assert.match(String(predecessor.reason), /revoked/i);
    assert.equal(predecessor.session, undefined);

    assert.deepEqual(
      backend.liveGrantIds(),
      [result.token.tokenId],
      "one arrangement, one live credential",
    );
  });

  await check("the replaced token cannot be renewed a second time", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueRegisteredCaregiverGrant();

    const first = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });
    assert.equal(first.ok, true);

    const replay = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });
    assert.equal(replay.ok, false, "a superseded token is spent, not reusable");
    assert.equal(replay.ok === false && replay.code, "GRANT_NOT_RENEWABLE");
  });

  await check("renewal restarts the caregiver window, it does not lengthen it", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const now = new Date("2026-03-01T12:00:00.000Z");
    const token = await issueRegisteredCaregiverGrant({ now });

    const renewedAt = new Date(now.getTime() + 6 * 24 * 60 * 60 * 1000);
    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId, renewedAt),
      },
      now: renewedAt,
    });

    assert.equal(result.ok, true, result.ok === false ? result.code : "");
    if (!result.ok) return;

    const issued = Date.parse(result.token.issuedAt);
    const ends = Date.parse(result.token.expiresAt);
    assert.equal(issued, renewedAt.getTime());
    assert.equal(
      ends - issued,
      CAREGIVER_CONSENT_DEFAULT_TTL_MS,
      "the successor carries the single caregiver default, not a longer window",
    );
    assert.equal(
      ends - Date.parse(token.expiresAt) < CAREGIVER_CONSENT_DEFAULT_TTL_MS,
      true,
      "renewal must not add the remaining time to a fresh full window",
    );
  });

  await check("the successor keeps the scope the owner already agreed", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueRegisteredCaregiverGrant();

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });
    assert.equal(result.ok, true);
    if (!result.ok) return;

    assert.equal(result.token.subjectAccountId, token.subjectAccountId);
    assert.equal(result.token.caregiverId, token.caregiverId);
    assert.deepEqual(result.token.permissions, token.permissions);
  });

  // --- owner confirmation --------------------------------------------------

  await check("renewal without an owner confirmation is refused", async () => {
    const backend = memoryBackend();
    setConsentRevocationBackendForTest(backend);
    const token = await issueRegisteredCaregiverGrant();

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: { tokenId: token.tokenId, token },
    });

    assert.equal(result.ok, false);
    assert.equal(
      result.ok === false && result.code,
      "OWNER_CONFIRMATION_REQUIRED",
    );
    assert.deepEqual(backend.liveGrantIds(), [token.tokenId]);
  });

  await check("a stale owner confirmation is refused", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueRegisteredCaregiverGrant();
    const longAgo = new Date(Date.now() - 60 * 60 * 1000);

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId, longAgo),
      },
    });

    assert.equal(
      result.ok,
      false,
      "an hour-old acknowledgement is not a confirmation of this request",
    );
    assert.equal(
      result.ok === false && result.code,
      "OWNER_CONFIRMATION_REQUIRED",
    );
  });

  await check(
    "a confirmation for a different grant cannot be replayed onto this one",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueRegisteredCaregiverGrant();
      const other = await issueRegisteredCaregiverGrant();

      const result = await handleCaregiverConsentRenewal({
        sessionUserId: OWNER,
        body: {
          tokenId: token.tokenId,
          token,
          ownerConfirmation: ownerConfirmation(other.tokenId),
        },
      });

      assert.equal(result.ok, false);
      assert.equal(
        result.ok === false && result.code,
        "OWNER_CONFIRMATION_REQUIRED",
      );
    },
  );

  // --- inherits the fail-closed revocation check ---------------------------

  await check("a revoked grant is not renewable", async () => {
    const backend = memoryBackend();
    setConsentRevocationBackendForTest(backend);
    const token = await issueRegisteredCaregiverGrant();

    const revoked = await handleConsentRevocation({
      sessionUserId: OWNER,
      body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId },
    });
    assert.equal(revoked.ok, true);

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });

    assert.equal(
      result.ok,
      false,
      "a withdrawn grant must not be reinstated by renewing it",
    );
    assert.equal(result.ok === false && result.code, "GRANT_NOT_RENEWABLE");
    assert.deepEqual(backend.liveGrantIds(), []);
  });

  await check(
    "renewal denies when the revocation store cannot be read",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueRegisteredCaregiverGrant();

      setConsentRevocationBackendForTest(outageBackend());
      const result = await handleCaregiverConsentRenewal({
        sessionUserId: OWNER,
        body: {
          tokenId: token.tokenId,
          token,
          ownerConfirmation: ownerConfirmation(token.tokenId),
        },
      });

      assert.equal(
        result.ok,
        false,
        "an outage must not be resolved in favour of extending access",
      );
      assert.equal(
        result.ok === false && result.code,
        "CONSENT_RENEWAL_FAILED",
      );
    },
  );

  // --- lapsed grants go back through granting -------------------------------

  await check("a grant that has run out is not renewable", async () => {
    const backend = memoryBackend();
    setConsentRevocationBackendForTest(backend);
    const token = await issueRegisteredCaregiverGrant({ ttlMs: -1000 });
    assert.equal((await verifyServerCaregiverConsentToken(token)).valid, false);

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });

    assert.equal(result.ok, false);
    assert.equal(
      result.ok === false && result.code,
      "GRANT_EXPIRED",
      "a lapsed arrangement is granted again, not renewed",
    );
    assert.deepEqual(
      backend.liveGrantIds(),
      [token.tokenId],
      "refusing a lapsed renewal leaves the record alone",
    );
  });

  // --- shape of the request -------------------------------------------------

  await check("renewal without the signed token is refused", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueRegisteredCaregiverGrant();

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });

    assert.equal(
      result.ok,
      false,
      "the agreed scope lives in the token, so a successor cannot be built without it",
    );
    assert.equal(result.ok === false && result.code, "GRANT_NOT_RENEWABLE");
  });

  await check("a token for a different grant cannot renew by proxy", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const mine = await issueRegisteredCaregiverGrant();
    const other = await issueRegisteredCaregiverGrant();

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: other.tokenId,
        token: mine,
        ownerConfirmation: ownerConfirmation(other.tokenId),
      },
    });

    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "GRANT_NOT_RENEWABLE");
  });

  await check("a missing tokenId is a validation error", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: { tokenId: "   " },
    });
    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "INVALID_TOKEN_ID");
  });

  await check("a coach grant is not renewable through this path", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const relationshipId = randomUUID();
    const token = await issueServerCoachConsentToken({
      tokenId: randomUUID(),
      relationshipId,
      clientAccountId: OWNER,
      coachId: COACH,
      permissions: COACH_PERMISSIONS,
      clientAffirmationHash: "affirmation-hash",
    });
    await recordConsentGrantIssued({
      tokenId: token.tokenId,
      grantKind: "coachClient",
      subjectAccountId: OWNER,
      partyId: COACH,
      relationshipId,
      issuedAt: token.issuedAt,
      expiresAt: token.expiresAt,
    });

    const result = await handleCaregiverConsentRenewal({
      sessionUserId: OWNER,
      body: {
        tokenId: token.tokenId,
        token,
        ownerConfirmation: ownerConfirmation(token.tokenId),
      },
    });

    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "GRANT_NOT_RENEWABLE");
  });

  // --- interruption ---------------------------------------------------------

  await check(
    "a renewal interrupted before it commits leaves one live credential",
    async () => {
      const backend = memoryBackend({ interruptBeforeCommit: true });
      setConsentRevocationBackendForTest(backend);
      const token = await issueRegisteredCaregiverGrant();

      const result = await handleCaregiverConsentRenewal({
        sessionUserId: OWNER,
        body: {
          tokenId: token.tokenId,
          token,
          ownerConfirmation: ownerConfirmation(token.tokenId),
        },
      });

      assert.equal(result.ok, false);
      assert.equal(
        result.ok === false && result.code,
        "CONSENT_RENEWAL_FAILED",
      );

      const live = backend.liveGrantIds();
      assert.equal(
        live.length <= 1,
        true,
        `an interrupted renewal left ${live.length} live credentials for one arrangement`,
      );
      assert.deepEqual(
        live,
        [token.tokenId],
        "an interruption should leave the arrangement as it was, not half-replaced",
      );
      assert.equal(
        (await verifyServerCaregiverConsentToken(token)).valid,
        true,
        "the caregiver keeps working until a successor actually exists",
      );
    },
  );

  await check(
    "the rejected two-write ordering is what the invariant catches",
    async () => {
      const backend = nonAtomicBackend({ interruptBetweenWrites: true });
      setConsentRevocationBackendForTest(backend);
      const token = await issueRegisteredCaregiverGrant();

      await handleCaregiverConsentRenewal({
        sessionUserId: OWNER,
        body: {
          tokenId: token.tokenId,
          token,
          ownerConfirmation: ownerConfirmation(token.tokenId),
        },
      });

      assert.equal(
        backend.liveGrantIds().length,
        2,
        "register-then-revoke, interrupted, is expected to strand two credentials — if this no longer holds, the atomicity assertions above have stopped meaning anything",
      );
    },
  );

  await check(
    "a backend that cannot swap in one step refuses rather than improvising",
    async () => {
      const backend = renewalUnsupportedBackend();
      setConsentRevocationBackendForTest(backend);
      const token = await issueRegisteredCaregiverGrant();

      const result = await handleCaregiverConsentRenewal({
        sessionUserId: OWNER,
        body: {
          tokenId: token.tokenId,
          token,
          ownerConfirmation: ownerConfirmation(token.tokenId),
        },
      });

      assert.equal(result.ok, false);
      assert.equal(result.ok === false && result.code, "GRANT_NOT_RENEWABLE");
      assert.deepEqual(
        backend.liveGrantIds(),
        [token.tokenId],
        "no successor may be registered by a backend that cannot withdraw the predecessor with it",
      );
    },
  );

  setConsentRevocationBackendForTest(null);
  return { failures };
}
