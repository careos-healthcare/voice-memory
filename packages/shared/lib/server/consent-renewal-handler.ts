import "server-only";

import { randomUUID } from "node:crypto";

import {
  CAREGIVER_CONSENT_REVOCATION_UNKNOWN_REASON,
  CAREGIVER_CONSENT_REVOKED_REASON,
  issueServerCaregiverConsentToken,
  verifyServerCaregiverConsentToken,
} from "@/lib/server/caregiver-consent-crypto";
import { authorizeConsentRevocation } from "@/lib/server/consent-revoke-authorization";
import { parsePresentedConsentToken } from "@/lib/server/consent-revoke-handler";
import {
  ConsentGrantNotRenewableError,
  ConsentRevocationStoreUnavailableError,
  renewConsentGrant,
} from "@/lib/server/consent-revocation-store";
import { logServerEvent } from "@/lib/server/structured-log";
import type { MonitoringConsentToken } from "@/types/caregiver";

/**
 * The body of `POST /api/coach/consent/renew`, minus the HTTP plumbing.
 *
 * Renewal exists so that a caregiving arrangement that is still wanted is not
 * ended by a calendar deadline. It is not a way for a short-lived credential
 * to become a long-lived one, so three properties hold and are each tested:
 *
 * 1. **The archive owner drives it.** Authorization is the session cookie, and
 *    the session has to belong to the account named as the grant's subject.
 *    The caregiver's own session fails, and the caregiver's token — the
 *    credential being renewed — carries no authority of its own here. A
 *    credential that can extend itself has whatever lifetime its holder wants.
 *
 * 2. **The owner says so each time.** The request must carry a confirmation
 *    the owner just gave, bound to the grant it renews and stale within
 *    minutes, so renewal cannot be wired to a timer without the client
 *    fabricating that confirmation. What the server can check is bounded — see
 *    `parseOwnerConfirmation` for what this does and does not establish.
 *
 * 3. **The window does not grow.** The successor is issued through the same
 *    single caregiver default as a first grant, and the predecessor is
 *    withdrawn in the same step that registers the successor.
 */

/** How long an owner's confirmation stays usable. */
const OWNER_CONFIRMATION_MAX_AGE_MS = 5 * 60 * 1000;

/** Tolerance for a device clock running ahead of the server's. */
const OWNER_CONFIRMATION_CLOCK_SKEW_MS = 60 * 1000;

/** Recorded against the superseded grant. A code, never free text. */
export const CONSENT_RENEWAL_SUPERSEDED_REASON = "superseded_by_renewal";

export type ConsentRenewalFailureCode =
  | "INVALID_TOKEN_ID"
  | "OWNER_CONFIRMATION_REQUIRED"
  | "FORBIDDEN"
  | "GRANT_EXPIRED"
  | "GRANT_NOT_RENEWABLE"
  | "CONSENT_RENEWAL_FAILED";

export type ConsentRenewalResult =
  | {
      ok: true;
      token: MonitoringConsentToken;
      previousTokenId: string;
      previousRevokedAt: string;
      /** Echoed back so the client can log which confirmation this acted on. */
      ownerConfirmedAt: string;
    }
  | { ok: false; code: ConsentRenewalFailureCode };

export interface OwnerRenewalConfirmation {
  acknowledgedAt: Date;
  confirmedTokenId: string;
}

/**
 * Reads the owner's confirmation off the request and checks it is fresh and
 * about this grant.
 *
 * Be clear about what this is worth. The session proves *who* is asking; this
 * field proves only that the client asserted a confirmation moments ago, for
 * this specific `tokenId`. It stops a stored blanket acknowledgement being
 * replayed against a different grant, and it stops renewal being driven off a
 * schedule without the client stating something untrue. It is not proof a
 * person tapped anything, and it is not treated as such anywhere below. The
 * available upgrade, if that proof is later required, is a server-issued
 * challenge the confirmation has to quote back.
 */
export function parseOwnerConfirmation(
  raw: unknown,
  tokenId: string,
  now: Date,
): OwnerRenewalConfirmation | null {
  if (!raw || typeof raw !== "object") return null;
  const input = raw as Record<string, unknown>;

  const confirmedTokenId =
    typeof input.confirmedTokenId === "string"
      ? input.confirmedTokenId.trim()
      : "";
  if (!confirmedTokenId || confirmedTokenId !== tokenId) return null;

  const acknowledgedAtRaw =
    typeof input.acknowledgedAt === "string" ? input.acknowledgedAt.trim() : "";
  if (!acknowledgedAtRaw) return null;

  const acknowledgedAt = new Date(acknowledgedAtRaw);
  if (Number.isNaN(acknowledgedAt.getTime())) return null;

  const ageMs = now.getTime() - acknowledgedAt.getTime();
  if (ageMs > OWNER_CONFIRMATION_MAX_AGE_MS) return null;
  if (ageMs < -OWNER_CONFIRMATION_CLOCK_SKEW_MS) return null;

  return { acknowledgedAt, confirmedTokenId };
}

function deny(
  code: ConsentRenewalFailureCode,
  denialCode: string,
): ConsentRenewalResult {
  logServerEvent(code === "FORBIDDEN" ? "auth_failure" : "api_error", {
    route: "coach/consent/renew",
    errorCode: code,
    internalCategory: code === "FORBIDDEN" ? "forbidden" : "validation",
    denialCode,
    consentDomain: "caregiverMonitoring",
  });
  return { ok: false, code };
}

/**
 * Issues a successor caregiver grant on the archive owner's instruction.
 *
 * Every refusal below is a refusal to extend access. There is no branch that
 * resolves an unknown state in favour of continuing — an unreachable
 * revocation list denies, exactly as it does on the verify path, because a
 * renewal granted during an outage would re-arm a grant the owner may already
 * have withdrawn.
 */
export async function handleCaregiverConsentRenewal(input: {
  sessionUserId: string;
  body: Record<string, unknown>;
  now?: Date;
}): Promise<ConsentRenewalResult> {
  const now = input.now ?? new Date();

  const tokenId =
    typeof input.body.tokenId === "string" ? input.body.tokenId.trim() : "";
  if (!tokenId) return { ok: false, code: "INVALID_TOKEN_ID" };

  // The presented token is evidence about the grant, not permission to renew
  // it. It is required because `consent_grants` records who and when but not
  // the agreed scope, and a successor whose permissions the server guessed
  // would widen or narrow access without the owner having seen the change.
  const presented = parsePresentedConsentToken(
    "caregiverMonitoring",
    input.body.token,
  );
  if (!presented || presented.grantKind !== "caregiverMonitoring") {
    return deny("GRANT_NOT_RENEWABLE", "token_not_presented");
  }
  const previousToken = presented.token;
  if (previousToken.tokenId !== tokenId) {
    return deny("GRANT_NOT_RENEWABLE", "token_id_mismatch");
  }

  let authorization;
  try {
    authorization = await authorizeConsentRevocation({
      sessionUserId: input.sessionUserId,
      tokenId,
      grantKind: "caregiverMonitoring",
      presentedToken: presented,
    });
  } catch (error) {
    return failClosed(error, "authorization_lookup_failed");
  }

  if (!authorization.allowed) {
    return deny("FORBIDDEN", authorization.denialCode);
  }

  const identity = authorization.identity;

  // Stated separately from the registry check above so the rule is legible
  // where it matters: the account renewing has to be the one the token names
  // as the archive owner. A caregiver presenting the very token being renewed
  // lands here, which is the failure mode this endpoint is shaped to refuse.
  if (previousToken.subjectAccountId !== input.sessionUserId) {
    const denialCode =
      previousToken.caregiverId === input.sessionUserId
        ? "caregiver_may_not_renew"
        : "not_grant_owner";
    return deny("FORBIDDEN", denialCode);
  }
  if (identity.subjectAccountId !== input.sessionUserId) {
    return deny("FORBIDDEN", "not_grant_owner");
  }
  if (
    identity.grantKind !== "caregiverMonitoring" ||
    previousToken.caregiverId !== identity.partyId
  ) {
    return deny("GRANT_NOT_RENEWABLE", "grant_identity_mismatch");
  }

  const confirmation = parseOwnerConfirmation(
    input.body.ownerConfirmation,
    tokenId,
    now,
  );
  if (!confirmation) {
    return deny("OWNER_CONFIRMATION_REQUIRED", "owner_confirmation_missing");
  }

  // Inherits the verify path wholesale: signature, lifetime, and the
  // revocation list, with the store's unavailability treated as a denial.
  const verification = await verifyServerCaregiverConsentToken(
    previousToken,
    now,
  );
  if (!verification.valid) {
    if (verification.reason === CAREGIVER_CONSENT_REVOCATION_UNKNOWN_REASON) {
      return failClosed(
        new Error(CAREGIVER_CONSENT_REVOCATION_UNKNOWN_REASON),
        "revocation_status_unknown",
      );
    }
    if (verification.reason === CAREGIVER_CONSENT_REVOKED_REASON) {
      return deny("GRANT_NOT_RENEWABLE", "grant_revoked");
    }
    // A grant that has run out is not renewed back to life. Re-granting is
    // the path for an arrangement that has lapsed, and it is the one that
    // shows the owner the scope and the party again before access resumes.
    if (now.toISOString() >= previousToken.expiresAt) {
      return deny("GRANT_EXPIRED", "grant_lapsed");
    }
    return deny("GRANT_NOT_RENEWABLE", "verification_failed");
  }

  // Same subject, same caregiver, same permissions, fresh identifier, and the
  // lifetime resolved from the one caregiver default rather than added to the
  // remaining time on the grant being replaced.
  const successor = await issueServerCaregiverConsentToken({
    tokenId: randomUUID(),
    subjectAccountId: identity.subjectAccountId,
    caregiverId: identity.partyId,
    permissions: previousToken.permissions,
    now,
  });

  try {
    const outcome = await renewConsentGrant({
      previousTokenId: tokenId,
      replacement: {
        tokenId: successor.tokenId,
        grantKind: "caregiverMonitoring",
        subjectAccountId: identity.subjectAccountId,
        partyId: identity.partyId,
        relationshipId: identity.relationshipId,
        issuedAt: successor.issuedAt,
        expiresAt: successor.expiresAt,
      },
      previousIssuedAt: identity.issuedAt ?? previousToken.issuedAt,
      previousExpiresAt: identity.expiresAt ?? previousToken.expiresAt,
      revokedBy: input.sessionUserId,
      revocationReason: CONSENT_RENEWAL_SUPERSEDED_REASON,
      now,
    });

    return {
      ok: true,
      token: successor,
      previousTokenId: outcome.previousTokenId,
      previousRevokedAt: outcome.previousRevokedAt,
      ownerConfirmedAt: confirmation.acknowledgedAt.toISOString(),
    };
  } catch (error) {
    if (error instanceof ConsentGrantNotRenewableError) {
      // The predecessor was withdrawn between verification and the write. The
      // successor was signed but never registered and is not returned, so the
      // arrangement is left ended rather than quietly restarted.
      return deny("GRANT_NOT_RENEWABLE", error.denialCode);
    }
    return failClosed(error, "renewal_write_failed");
  }
}

function failClosed(error: unknown, denialCode: string): ConsentRenewalResult {
  logServerEvent("api_error", {
    route: "coach/consent/renew",
    errorCode: "CONSENT_RENEWAL_FAILED",
    internalCategory: "internal_error",
    consentDomain: "caregiverMonitoring",
    denialCode,
    storeUnavailable: error instanceof ConsentRevocationStoreUnavailableError,
    failedClosed: true,
    message: error instanceof Error ? error.message : String(error),
  });
  return { ok: false, code: "CONSENT_RENEWAL_FAILED" };
}
