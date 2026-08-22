import type {
  CoachConsentToken,
  CoachSharingPermissions,
  CoachTokenVerificationResult,
} from "@/types/coach-client-relationship";

export const COACH_CONSENT_POLICY_VERSION = 1;

export interface VerifyCoachConsentOptions {
  now?: Date;
  /** HMAC secret — device-bound on mobile; server-held in production. */
  signingSecret: string;
}

export interface IssueCoachConsentOptions extends VerifyCoachConsentOptions {
  tokenId: string;
  relationshipId: string;
  clientAccountId: string;
  coachId: string;
  permissions: CoachSharingPermissions;
  clientAffirmationHash: string;
  ttlMs?: number;
}

function sortMap(input: Record<string, unknown>): Record<string, unknown> {
  const keys = Object.keys(input).sort();
  const out: Record<string, unknown> = {};
  for (const key of keys) {
    const value = input[key];
    if (value && typeof value === "object" && !Array.isArray(value)) {
      out[key] = sortMap(value as Record<string, unknown>);
    } else if (Array.isArray(value)) {
      out[key] = [...value];
    } else {
      out[key] = value;
    }
  }
  return out;
}

export function coachConsentCanonicalPayload(
  token: Omit<CoachConsentToken, "signature">,
): Record<string, unknown> {
  return {
    tokenId: token.tokenId,
    relationshipId: token.relationshipId,
    clientAccountId: token.clientAccountId,
    coachId: token.coachId,
    permissions: {
      factLedger: token.permissions.factLedger,
      confidenceBandedInsights: token.permissions.confidenceBandedInsights,
      insightKinds: [...token.permissions.insightKinds].sort(),
    },
    issuedAt: token.issuedAt,
    expiresAt: token.expiresAt,
    policyVersion: token.policyVersion,
    clientAffirmationHash: token.clientAffirmationHash,
  };
}

/** Node / test helper — mirrors mobile HMAC canonical signing. */
export async function signCoachConsentPayload(
  payload: Record<string, unknown>,
  signingSecret: string,
): Promise<string> {
  const canonical = JSON.stringify(sortMap(payload));
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(signingSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(canonical),
  );
  return [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function hashClientAffirmation(text: string): string {
  // Structural placeholder — mobile uses crypto package sha256 synchronously.
  let hash = 0;
  for (const char of text.trim()) {
    hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}

export async function issueCoachConsentToken(
  options: IssueCoachConsentOptions,
): Promise<CoachConsentToken> {
  const now = options.now ?? new Date();
  const issuedAt = now.toISOString();
  const expiresAt = new Date(
    now.getTime() + (options.ttlMs ?? 1000 * 60 * 60 * 24 * 90),
  ).toISOString();

  const draft = {
    tokenId: options.tokenId,
    relationshipId: options.relationshipId,
    clientAccountId: options.clientAccountId,
    coachId: options.coachId,
    permissions: options.permissions,
    issuedAt,
    expiresAt,
    policyVersion: COACH_CONSENT_POLICY_VERSION,
    clientAffirmationHash: options.clientAffirmationHash,
  };

  const signature = await signCoachConsentPayload(
    coachConsentCanonicalPayload(draft),
    options.signingSecret,
  );

  return { ...draft, signature };
}

export async function verifyCoachConsentToken(
  token: CoachConsentToken,
  options: VerifyCoachConsentOptions,
): Promise<CoachTokenVerificationResult> {
  const now = (options.now ?? new Date()).toISOString();

  if (token.policyVersion !== COACH_CONSENT_POLICY_VERSION) {
    return { valid: false, reason: "Unsupported coach consent policy version" };
  }

  if (
    !token.tokenId ||
    !token.relationshipId ||
    !token.clientAccountId ||
    !token.coachId ||
    !token.clientAffirmationHash
  ) {
    return { valid: false, reason: "Incomplete coach consent token" };
  }

  if (now >= token.expiresAt) {
    return { valid: false, reason: "Coach consent token expired" };
  }

  if (now < token.issuedAt) {
    return { valid: false, reason: "Coach consent token not yet valid" };
  }

  const { signature, ...unsigned } = token;
  const expected = await signCoachConsentPayload(
    coachConsentCanonicalPayload(unsigned),
    options.signingSecret,
  );

  if (expected.length !== signature.length) {
    return { valid: false, reason: "Invalid coach consent signature" };
  }

  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  if (diff !== 0) {
    return { valid: false, reason: "Invalid coach consent signature" };
  }

  return {
    valid: true,
    session: {
      sessionId: `coach_${token.tokenId}`,
      mode: "professionalCoach",
      coachId: token.coachId,
      clientAccountId: token.clientAccountId,
      relationshipId: token.relationshipId,
      permissions: token.permissions,
      tokenId: token.tokenId,
      startedAt: now,
      expiresAt: token.expiresAt,
      validatedAt: now,
    },
  };
}
