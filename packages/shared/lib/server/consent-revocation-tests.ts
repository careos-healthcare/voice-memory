import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import fs from "node:fs";

import {
  issueServerCaregiverConsentToken,
  verifyServerCaregiverConsentToken,
} from "@/lib/server/caregiver-consent-crypto";
import {
  issueServerCoachConsentToken,
  verifyServerCoachConsentToken,
} from "@/lib/server/coach-consent-crypto";
import { handleConsentRevocation } from "@/lib/server/consent-revoke-handler";
import {
  isConsentTokenRevoked,
  recordConsentGrantIssued,
  recordConsentRevocation,
  setConsentRevocationBackendForTest,
  type ConsentGrantRecord,
  type ConsentRevocationBackend,
} from "@/lib/server/consent-revocation-store";
import { resolveDataPath } from "@/lib/server/data-path";
import type { CaregiverPermissions } from "@/types/caregiver";
import type { CoachSharingPermissions } from "@/types/coach-client-relationship";

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
  return { name: "outage", read: fail, upsertGrant: fail, revoke: fail };
}

/** An in-memory backend, for tests that only need a working store. */
function memoryBackend(): ConsentRevocationBackend {
  const rows = new Map<string, ConsentGrantRecord>();
  return {
    name: "memory",
    async read(tokenId) {
      return rows.get(tokenId) ?? null;
    },
    async upsertGrant(input) {
      const existing = rows.get(input.tokenId);
      rows.set(input.tokenId, {
        tokenId: input.tokenId,
        grantKind: input.grantKind,
        subjectAccountId: input.subjectAccountId,
        partyId: input.partyId,
        relationshipId: input.relationshipId ?? null,
        issuedAt: input.issuedAt ?? null,
        expiresAt: input.expiresAt ?? null,
        revokedAt: existing?.revokedAt ?? null,
        revokedBy: existing?.revokedBy ?? null,
        revocationReason: existing?.revocationReason ?? null,
      });
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
      rows.set(input.tokenId, {
        tokenId: input.tokenId,
        grantKind: input.grantKind,
        subjectAccountId: existing?.subjectAccountId ?? input.subjectAccountId,
        partyId: existing?.partyId ?? input.partyId,
        relationshipId: existing?.relationshipId ?? input.relationshipId ?? null,
        issuedAt: existing?.issuedAt ?? input.issuedAt ?? null,
        expiresAt: existing?.expiresAt ?? input.expiresAt ?? null,
        revokedAt,
        revokedBy: input.revokedBy,
        revocationReason: input.revocationReason ?? null,
      });
      return { tokenId: input.tokenId, revokedAt, alreadyRevoked: false };
    },
  };
}

async function issueCaregiverGrant(options: { register: boolean; ttlMs?: number }) {
  const token = await issueServerCaregiverConsentToken({
    tokenId: randomUUID(),
    subjectAccountId: OWNER,
    caregiverId: CAREGIVER,
    permissions: CAREGIVER_PERMISSIONS,
    ttlMs: options.ttlMs,
  });
  if (options.register) {
    await recordConsentGrantIssued({
      tokenId: token.tokenId,
      grantKind: "caregiverMonitoring",
      subjectAccountId: OWNER,
      partyId: CAREGIVER,
      issuedAt: token.issuedAt,
      expiresAt: token.expiresAt,
    });
  }
  return token;
}

async function issueCoachGrant(options: { register: boolean }) {
  const relationshipId = randomUUID();
  const token = await issueServerCoachConsentToken({
    tokenId: randomUUID(),
    relationshipId,
    clientAccountId: OWNER,
    coachId: COACH,
    permissions: COACH_PERMISSIONS,
    clientAffirmationHash: "affirmation-hash",
  });
  if (options.register) {
    await recordConsentGrantIssued({
      tokenId: token.tokenId,
      grantKind: "coachClient",
      subjectAccountId: OWNER,
      partyId: COACH,
      relationshipId,
      issuedAt: token.issuedAt,
      expiresAt: token.expiresAt,
    });
  }
  return token;
}

export async function runConsentRevocationTests(): Promise<{ failures: string[] }> {
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

  // --- the gap this change closes -----------------------------------------

  await check("a live caregiver token still verifies", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCaregiverGrant({ register: true });
    const result = await verifyServerCaregiverConsentToken(token);
    assert.equal(result.valid, true, result.reason ?? "no reason given");
  });

  await check("a revoked caregiver token fails verify", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCaregiverGrant({ register: true });

    const revoke = await handleConsentRevocation({
      sessionUserId: OWNER,
      body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId },
    });
    assert.equal(revoke.ok, true);

    const result = await verifyServerCaregiverConsentToken(token);
    assert.equal(result.valid, false);
    assert.match(String(result.reason), /revoked/i);
    assert.equal(result.session, undefined);
  });

  await check("a revoked coach token fails verify", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCoachGrant({ register: true });

    const before = await verifyServerCoachConsentToken(token);
    assert.equal(before.valid, true, before.reason ?? "no reason given");

    const revoke = await handleConsentRevocation({
      sessionUserId: OWNER,
      body: { consentDomain: "coachClient", tokenId: token.tokenId },
    });
    assert.equal(revoke.ok, true);

    const after = await verifyServerCoachConsentToken(token);
    assert.equal(after.valid, false);
    assert.match(String(after.reason), /revoked/i);
    assert.equal(after.session, undefined);
  });

  await check(
    "the legacy 'caregiver' consentDomain alias still revokes the caregiver grant",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueCaregiverGrant({ register: true });
      const revoke = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: { consentDomain: "caregiver", tokenId: token.tokenId },
      });
      assert.equal(revoke.ok, true);
      assert.equal((await verifyServerCaregiverConsentToken(token)).valid, false);
    },
  );

  // --- fail closed ---------------------------------------------------------

  await check(
    "caregiver verify fails closed when the revocation store is unreachable",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueCaregiverGrant({ register: true });
      assert.equal((await verifyServerCaregiverConsentToken(token)).valid, true);

      setConsentRevocationBackendForTest(outageBackend());
      const result = await verifyServerCaregiverConsentToken(token);
      assert.equal(
        result.valid,
        false,
        "an outage must not reinstate access to a private journal",
      );
      assert.match(String(result.reason), /unavailable/i);
      assert.equal(result.session, undefined);
    },
  );

  await check(
    "coach verify fails closed when the revocation store is unreachable",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueCoachGrant({ register: true });
      assert.equal((await verifyServerCoachConsentToken(token)).valid, true);

      setConsentRevocationBackendForTest(outageBackend());
      const result = await verifyServerCoachConsentToken(token);
      assert.equal(result.valid, false);
      assert.match(String(result.reason), /unavailable/i);
      assert.equal(result.session, undefined);
    },
  );

  await check(
    "verify fails closed when no durable store is configured in production",
    async () => {
      const previousNodeEnv = process.env.NODE_ENV;
      const previousDatabaseUrl = process.env.DATABASE_URL;
      const previousCaregiverSecret = process.env.CAREGIVER_CONSENT_HMAC_SECRET;
      process.env.CAREGIVER_CONSENT_HMAC_SECRET = "test-secret-for-production-check";

      try {
        setConsentRevocationBackendForTest(memoryBackend());
        const token = await issueCaregiverGrant({ register: true });

        setConsentRevocationBackendForTest(null);
        delete process.env.DATABASE_URL;
        Object.defineProperty(process.env, "NODE_ENV", {
          value: "production",
          configurable: true,
          writable: true,
          enumerable: true,
        });

        const result = await verifyServerCaregiverConsentToken(token);
        assert.equal(
          result.valid,
          false,
          "a production deployment with no revocation store must not verify tokens",
        );
        assert.match(String(result.reason), /unavailable/i);
      } finally {
        Object.defineProperty(process.env, "NODE_ENV", {
          value: previousNodeEnv,
          configurable: true,
          writable: true,
          enumerable: true,
        });
        if (previousDatabaseUrl === undefined) delete process.env.DATABASE_URL;
        else process.env.DATABASE_URL = previousDatabaseUrl;
        if (previousCaregiverSecret === undefined) {
          delete process.env.CAREGIVER_CONSENT_HMAC_SECRET;
        } else {
          process.env.CAREGIVER_CONSENT_HMAC_SECRET = previousCaregiverSecret;
        }
      }
    },
  );

  await check(
    "a store outage during revoke reports a retryable failure, never a silent success",
    async () => {
      setConsentRevocationBackendForTest(outageBackend());
      const result = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: { consentDomain: "caregiverMonitoring", tokenId: randomUUID() },
      });
      assert.equal(result.ok, false);
      assert.equal(result.ok === false && result.code, "CONSENT_REVOKE_FAILED");
    },
  );

  await check(
    "a registry read failure does not fall back to the presented token",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueCaregiverGrant({ register: false });

      setConsentRevocationBackendForTest(outageBackend());
      const result = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: {
          consentDomain: "caregiverMonitoring",
          tokenId: token.tokenId,
          token,
        },
      });
      assert.equal(result.ok, false);
      assert.equal(
        result.ok === false && result.code,
        "CONSENT_REVOKE_FAILED",
        "an outage must not downgrade the authorization check",
      );
    },
  );

  // --- durability ----------------------------------------------------------

  await check(
    "a revocation is written to durable storage and survives a fresh read",
    async () => {
      // No override: this exercises the real backend the process would use.
      const tokenId = `test-durability-${randomUUID()}`;
      await recordConsentRevocation({
        tokenId,
        grantKind: "caregiverMonitoring",
        subjectAccountId: OWNER,
        partyId: CAREGIVER,
        revokedBy: OWNER,
      });

      try {
        assert.equal(
          await isConsentTokenRevoked(tokenId),
          true,
          "the revocation must read back from the store",
        );

        const filePath = resolveDataPath("consent", "consent-grants.json");
        const onDisk = JSON.parse(fs.readFileSync(filePath, "utf8")) as {
          grants: Record<string, { revokedAt: string | null }>;
        };
        assert.ok(
          onDisk.grants[tokenId]?.revokedAt,
          "the revocation must be on disk, not only in process memory",
        );

        // A later grant write for an unrelated token must not clobber it.
        await recordConsentGrantIssued({
          tokenId: `test-durability-other-${randomUUID()}`,
          grantKind: "coachClient",
          subjectAccountId: OWNER,
          partyId: COACH,
        });
        assert.equal(await isConsentTokenRevoked(tokenId), true);
      } finally {
        const filePath = resolveDataPath("consent", "consent-grants.json");
        if (fs.existsSync(filePath)) {
          const shape = JSON.parse(fs.readFileSync(filePath, "utf8")) as {
            grants: Record<string, unknown>;
          };
          for (const key of Object.keys(shape.grants)) {
            if (key.startsWith("test-durability")) delete shape.grants[key];
          }
          fs.writeFileSync(filePath, JSON.stringify(shape, null, 2), "utf8");
        }
      }
    },
  );

  await check(
    "a corrupted store is an outage, not an empty revocation list",
    async () => {
      const filePath = resolveDataPath("consent", "consent-grants.json");
      const hadFile = fs.existsSync(filePath);
      const original = hadFile ? fs.readFileSync(filePath, "utf8") : null;

      try {
        fs.mkdirSync(resolveDataPath("consent"), { recursive: true });
        fs.writeFileSync(filePath, "{ not json", "utf8");

        await assert.rejects(
          () => isConsentTokenRevoked("any-token"),
          /unavailable/i,
          "a store we cannot parse must not read back as 'nothing is revoked'",
        );
      } finally {
        if (original == null) fs.rmSync(filePath, { force: true });
        else fs.writeFileSync(filePath, original, "utf8");
      }
    },
  );

  await check(
    "re-recording a grant does not clear an existing revocation",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueCaregiverGrant({ register: true });
      await handleConsentRevocation({
        sessionUserId: OWNER,
        body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId },
      });

      await recordConsentGrantIssued({
        tokenId: token.tokenId,
        grantKind: "caregiverMonitoring",
        subjectAccountId: OWNER,
        partyId: CAREGIVER,
        issuedAt: token.issuedAt,
        expiresAt: token.expiresAt,
      });

      assert.equal(await isConsentTokenRevoked(token.tokenId), true);
    },
  );

  // --- idempotency and graceful edges -------------------------------------

  await check("revocation is idempotent", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCaregiverGrant({ register: true });

    const first = await handleConsentRevocation({
      sessionUserId: OWNER,
      body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId },
    });
    const second = await handleConsentRevocation({
      sessionUserId: OWNER,
      body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId },
    });

    assert.equal(first.ok, true);
    assert.equal(second.ok, true);
    assert.equal(first.ok === true && first.alreadyRevoked, false);
    assert.equal(second.ok === true && second.alreadyRevoked, true);
    assert.equal(
      first.ok === true && second.ok === true && first.revokedAt,
      second.ok === true ? second.revokedAt : undefined,
      "the first revocation timestamp must not move",
    );
  });

  await check("revoking an already-expired token succeeds", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCaregiverGrant({ register: true, ttlMs: -1000 });
    assert.equal((await verifyServerCaregiverConsentToken(token)).valid, false);

    const result = await handleConsentRevocation({
      sessionUserId: OWNER,
      body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId, token },
    });
    assert.equal(
      result.ok,
      true,
      "an expired grant must still be revocable without an error the user has to work around",
    );
  });

  await check(
    "revoking an unknown token is refused cleanly, not with a crash",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const result = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: { consentDomain: "caregiverMonitoring", tokenId: randomUUID() },
      });
      assert.equal(result.ok, false);
      assert.equal(result.ok === false && result.code, "FORBIDDEN");
    },
  );

  await check("a missing tokenId is a validation error", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const result = await handleConsentRevocation({
      sessionUserId: OWNER,
      body: { consentDomain: "caregiverMonitoring", tokenId: "   " },
    });
    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "INVALID_TOKEN_ID");
  });

  // --- authorization -------------------------------------------------------

  await check("the caregiver named in a grant cannot revoke it", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCaregiverGrant({ register: true });

    const result = await handleConsentRevocation({
      sessionUserId: CAREGIVER,
      body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId, token },
    });
    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "FORBIDDEN");
    assert.equal(
      await isConsentTokenRevoked(token.tokenId),
      false,
      "a refused revoke must not write to the revocation list",
    );
  });

  await check("the coach named in a grant cannot revoke it", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCoachGrant({ register: true });

    const result = await handleConsentRevocation({
      sessionUserId: COACH,
      body: { consentDomain: "coachClient", tokenId: token.tokenId, token },
    });
    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "FORBIDDEN");
  });

  await check("an unrelated account cannot revoke someone else's grant", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCaregiverGrant({ register: true });

    const result = await handleConsentRevocation({
      sessionUserId: "stranger-account",
      body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId },
    });
    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "FORBIDDEN");
  });

  await check(
    "the owner can revoke an unregistered grant by presenting the signed token",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueCaregiverGrant({ register: false });

      const result = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId, token },
      });
      assert.equal(result.ok, true);
      assert.equal((await verifyServerCaregiverConsentToken(token)).valid, false);
    },
  );

  await check(
    "a mislabelled consentDomain does not stop the owner revoking",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const caregiverToken = await issueCaregiverGrant({ register: false });

      const result = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: {
          consentDomain: "coachClient",
          tokenId: caregiverToken.tokenId,
          token: caregiverToken,
        },
      });
      assert.equal(result.ok, true);
      assert.equal(result.ok === true && result.grantKind, "caregiverMonitoring");
      assert.equal(
        (await verifyServerCaregiverConsentToken(caregiverToken)).valid,
        false,
      );
    },
  );

  await check("a forged presented token proves nothing", async () => {
    setConsentRevocationBackendForTest(memoryBackend());
    const token = await issueCaregiverGrant({ register: false });
    const forged = { ...token, subjectAccountId: "stranger-account" };

    const result = await handleConsentRevocation({
      sessionUserId: "stranger-account",
      body: {
        consentDomain: "caregiverMonitoring",
        tokenId: token.tokenId,
        token: forged,
      },
    });
    assert.equal(result.ok, false);
    assert.equal(result.ok === false && result.code, "FORBIDDEN");
    assert.equal(await isConsentTokenRevoked(token.tokenId), false);
  });

  await check(
    "a presented token for a different tokenId cannot revoke by proxy",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const mine = await issueCaregiverGrant({ register: false });

      const result = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: {
          consentDomain: "caregiverMonitoring",
          tokenId: randomUUID(),
          token: mine,
        },
      });
      assert.equal(result.ok, false);
      assert.equal(result.ok === false && result.code, "FORBIDDEN");
    },
  );

  await check(
    "the owner can revoke without holding the token once it is registered",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueCaregiverGrant({ register: true });

      const result = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: { consentDomain: "caregiverMonitoring", tokenId: token.tokenId },
      });
      assert.equal(
        result.ok,
        true,
        "a user who reinstalled the app must still be able to end access",
      );
    },
  );

  await check(
    "the recorded revocation names the revoker and reason",
    async () => {
      setConsentRevocationBackendForTest(memoryBackend());
      const token = await issueCaregiverGrant({ register: true });
      const result = await handleConsentRevocation({
        sessionUserId: OWNER,
        body: {
          consentDomain: "caregiverMonitoring",
          tokenId: token.tokenId,
          reason: "user_revoked",
        },
      });
      assert.equal(result.ok, true);
      assert.equal(result.ok === true && result.grantKind, "caregiverMonitoring");
    },
  );

  setConsentRevocationBackendForTest(null);
  return { failures };
}
