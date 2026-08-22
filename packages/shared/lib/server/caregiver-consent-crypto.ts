import "server-only";

import {
  caregiverConsentCanonicalPayload,
  issueMonitoringConsentToken,
  signCaregiverConsentPayload,
  verifyMonitoringConsentToken,
} from "@/lib/caregiver/consent-verification";
import {
  ConsentRevocationStoreUnavailableError,
  isConsentTokenRevoked,
} from "@/lib/server/consent-revocation-store";
import { logServerEvent } from "@/lib/server/structured-log";
import type {
  CaregiverPermissions,
  CaregiverTokenVerificationResult,
  MonitoringConsentToken,
} from "@/types/caregiver";

export const CAREGIVER_CONSENT_REVOKED_REASON = "Consent token revoked";
export const CAREGIVER_CONSENT_REVOCATION_UNKNOWN_REASON =
  "Consent revocation status is unavailable";

function caregiverConsentSecret(): string {
  const secret = process.env.CAREGIVER_CONSENT_HMAC_SECRET;
  if (!secret) {
    if (process.env.NODE_ENV === "production") {
      throw new Error(
        "CAREGIVER_CONSENT_HMAC_SECRET is required in production",
      );
    }
    return "dev-only-caregiver-consent-secret-change-me";
  }
  return secret;
}

export interface IssueServerCaregiverConsentInput {
  tokenId: string;
  subjectAccountId: string;
  caregiverId: string;
  permissions: CaregiverPermissions;
  /** Omit to take the single default from `@/lib/consent/consent-token-ttl`. */
  ttlMs?: number;
  now?: Date;
}

export async function issueServerCaregiverConsentToken(
  input: IssueServerCaregiverConsentInput,
): Promise<MonitoringConsentToken> {
  return issueMonitoringConsentToken({
    ...input,
    signingSecret: caregiverConsentSecret(),
  });
}

/**
 * Signature check only — no expiry, no revocation lookup.
 *
 * Used solely to establish who a token belongs to when authorizing a revoke.
 * An expired or already-revoked token still proves ownership, and the owner of
 * a token they can no longer use must still be able to revoke it. Never use
 * this to decide whether a token grants access.
 */
export async function caregiverConsentTokenSignatureIsValid(
  token: MonitoringConsentToken,
): Promise<boolean> {
  const { signature, ...unsigned } = token;
  if (!signature) return false;

  const expected = await signCaregiverConsentPayload(
    caregiverConsentCanonicalPayload(unsigned),
    caregiverConsentSecret(),
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
 * list.
 *
 * Fails closed: if revocation status cannot be read, the token is reported
 * invalid. It is never reported valid on the strength of the signature alone,
 * because a withdrawn grant and a live one have identical signatures.
 */
export async function verifyServerCaregiverConsentToken(
  token: MonitoringConsentToken,
  now?: Date,
): Promise<CaregiverTokenVerificationResult> {
  const stateless = await verifyMonitoringConsentToken(token, {
    now,
    signingSecret: caregiverConsentSecret(),
  });

  if (!stateless.valid) return stateless;

  try {
    if (await isConsentTokenRevoked(token.tokenId)) {
      return { valid: false, reason: CAREGIVER_CONSENT_REVOKED_REASON };
    }
  } catch (error) {
    logServerEvent("api_error", {
      route: "coach/consent/verify",
      errorCode: "CONSENT_REVOCATION_STORE_UNAVAILABLE",
      internalCategory: "internal_error",
      consentDomain: "caregiverMonitoring",
      failedClosed: true,
      message:
        error instanceof ConsentRevocationStoreUnavailableError
          ? error.message
          : String(error),
    });
    return { valid: false, reason: CAREGIVER_CONSENT_REVOCATION_UNKNOWN_REASON };
  }

  return stateless;
}
