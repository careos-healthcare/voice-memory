import "server-only";

import {
  issueMonitoringConsentToken,
  verifyMonitoringConsentToken,
} from "@/lib/caregiver/consent-verification";
import type {
  CaregiverPermissions,
  CaregiverTokenVerificationResult,
  MonitoringConsentToken,
} from "@/types/caregiver";

const DEFAULT_TTL_MS = 1000 * 60 * 60 * 24 * 30;

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
  ttlMs?: number;
  now?: Date;
}

export async function issueServerCaregiverConsentToken(
  input: IssueServerCaregiverConsentInput,
): Promise<MonitoringConsentToken> {
  return issueMonitoringConsentToken({
    ...input,
    signingSecret: caregiverConsentSecret(),
    ttlMs: input.ttlMs ?? DEFAULT_TTL_MS,
  });
}

export async function verifyServerCaregiverConsentToken(
  token: MonitoringConsentToken,
  now?: Date,
): Promise<CaregiverTokenVerificationResult> {
  return verifyMonitoringConsentToken(token, {
    now,
    signingSecret: caregiverConsentSecret(),
  });
}
