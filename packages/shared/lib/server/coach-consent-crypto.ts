import "server-only";

import {
  coachConsentCanonicalPayload,
  issueCoachConsentToken,
  signCoachConsentPayload,
  verifyCoachConsentToken,
} from "@/lib/coach/client-consent-verification";
import {
  ConsentRevocationStoreUnavailableError,
  isConsentTokenRevoked,
} from "@/lib/server/consent-revocation-store";
import { logServerEvent } from "@/lib/server/structured-log";
import type {
  CoachConsentToken,
  CoachSharingPermissions,
  CoachTokenVerificationResult,
} from "@/types/coach-client-relationship";

export const COACH_CONSENT_REVOKED_REASON = "Coach consent token revoked";
export const COACH_CONSENT_REVOCATION_UNKNOWN_REASON =
  "Coach consent revocation status is unavailable";

function coachConsentSecret(): string {
  const secret = process.env.COACH_CONSENT_HMAC_SECRET;
  if (!secret) {
    if (process.env.NODE_ENV === "production") {
      throw new Error("COACH_CONSENT_HMAC_SECRET is required in production");
    }
    return "dev-only-coach-consent-secret-change-me";
  }
  return secret;
}

export interface IssueServerCoachConsentInput {
  tokenId: string;
  relationshipId: string;
  clientAccountId: string;
  coachId: string;
  permissions: CoachSharingPermissions;
  clientAffirmationHash: string;
  /** Omit to take the single default from `@/lib/consent/consent-token-ttl`. */
  ttlMs?: number;
  now?: Date;
}

export async function issueServerCoachConsentToken(
  input: IssueServerCoachConsentInput,
): Promise<CoachConsentToken> {
  return issueCoachConsentToken({
    ...input,
    signingSecret: coachConsentSecret(),
  });
}

/**
 * Signature check only — no expiry, no revocation lookup. Establishes token
 * ownership when authorizing a revoke; see the caregiver equivalent for why
 * this must never be used to decide access.
 */
export async function coachConsentTokenSignatureIsValid(
  token: CoachConsentToken,
): Promise<boolean> {
  const { signature, ...unsigned } = token;
  if (!signature) return false;

  const expected = await signCoachConsentPayload(
    coachConsentCanonicalPayload(unsigned),
    coachConsentSecret(),
  );
  if (expected.length !== signature.length) return false;

  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

/**
 * Verifies the signature and lifetime, then checks the server-side revocation
 * list. Fails closed for the same reason the caregiver path does — see
 * `verifyServerCaregiverConsentToken`.
 *
 * The coach path reads no caregiver feature flag and is issued independently of
 * caregiver monitoring, so it needs its own revocation check rather than
 * inheriting one.
 */
export async function verifyServerCoachConsentToken(
  token: CoachConsentToken,
  now?: Date,
): Promise<CoachTokenVerificationResult> {
  const stateless = await verifyCoachConsentToken(token, {
    now,
    signingSecret: coachConsentSecret(),
  });

  if (!stateless.valid) return stateless;

  try {
    if (await isConsentTokenRevoked(token.tokenId)) {
      return { valid: false, reason: COACH_CONSENT_REVOKED_REASON };
    }
  } catch (error) {
    logServerEvent("api_error", {
      route: "coach/consent/verify",
      errorCode: "CONSENT_REVOCATION_STORE_UNAVAILABLE",
      internalCategory: "internal_error",
      consentDomain: "coachClient",
      failedClosed: true,
      message:
        error instanceof ConsentRevocationStoreUnavailableError
          ? error.message
          : String(error),
    });
    return { valid: false, reason: COACH_CONSENT_REVOCATION_UNKNOWN_REASON };
  }

  return stateless;
}
