import "server-only";

import {
  issueCoachConsentToken,
  verifyCoachConsentToken,
} from "@/lib/coach/client-consent-verification";
import type {
  CoachConsentToken,
  CoachSharingPermissions,
  CoachTokenVerificationResult,
} from "@/types/coach-client-relationship";

const DEFAULT_TTL_MS = 1000 * 60 * 60 * 24 * 90;

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
  ttlMs?: number;
  now?: Date;
}

export async function issueServerCoachConsentToken(
  input: IssueServerCoachConsentInput,
): Promise<CoachConsentToken> {
  return issueCoachConsentToken({
    ...input,
    signingSecret: coachConsentSecret(),
    ttlMs: input.ttlMs ?? DEFAULT_TTL_MS,
  });
}

export async function verifyServerCoachConsentToken(
  token: CoachConsentToken,
  now?: Date,
): Promise<CoachTokenVerificationResult> {
  return verifyCoachConsentToken(token, {
    now,
    signingSecret: coachConsentSecret(),
  });
}
