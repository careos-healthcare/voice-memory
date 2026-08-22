import { resolveCaregiverConsentTtlMs } from "@/lib/consent/consent-token-ttl";
import type {
  CaregiverPermissions,
  CaregiverSession,
  CaregiverTokenVerificationResult,
  MonitoringConsentToken,
} from "@/types/caregiver";

export const CAREGIVER_CONSENT_POLICY_VERSION = 1;

export interface VerifyCaregiverConsentOptions {
  now?: Date;
  /** HMAC secret — server-held in production. */
  signingSecret: string;
}

export interface IssueCaregiverConsentOptions extends VerifyCaregiverConsentOptions {
  tokenId: string;
  subjectAccountId: string;
  caregiverId: string;
  permissions: CaregiverPermissions;
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

export function caregiverConsentCanonicalPayload(
  token: Omit<MonitoringConsentToken, "signature">,
): Record<string, unknown> {
  return {
    tokenId: token.tokenId,
    subjectAccountId: token.subjectAccountId,
    caregiverId: token.caregiverId,
    permissions: {
      evidenceStreamIds: [...token.permissions.evidenceStreamIds].sort(),
      reviewSummaries: token.permissions.reviewSummaries,
      thresholdAlerts: token.permissions.thresholdAlerts,
    },
    issuedAt: token.issuedAt,
    expiresAt: token.expiresAt,
    policyVersion: token.policyVersion,
  };
}

export async function signCaregiverConsentPayload(
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

export async function issueMonitoringConsentToken(
  options: IssueCaregiverConsentOptions,
): Promise<MonitoringConsentToken> {
  const now = options.now ?? new Date();
  const issuedAt = now.toISOString();
  const expiresAt = new Date(
    now.getTime() + resolveCaregiverConsentTtlMs(options.ttlMs),
  ).toISOString();

  const draft = {
    tokenId: options.tokenId,
    subjectAccountId: options.subjectAccountId,
    caregiverId: options.caregiverId,
    permissions: options.permissions,
    issuedAt,
    expiresAt,
    policyVersion: CAREGIVER_CONSENT_POLICY_VERSION,
  };

  const signature = await signCaregiverConsentPayload(
    caregiverConsentCanonicalPayload(draft),
    options.signingSecret,
  );

  return { ...draft, signature };
}

export async function verifyMonitoringConsentToken(
  token: MonitoringConsentToken,
  options: VerifyCaregiverConsentOptions,
): Promise<CaregiverTokenVerificationResult> {
  const now = (options.now ?? new Date()).toISOString();

  if (token.policyVersion !== CAREGIVER_CONSENT_POLICY_VERSION) {
    return { valid: false, reason: "Unsupported consent policy version" };
  }

  if (!token.tokenId || !token.subjectAccountId || !token.caregiverId) {
    return { valid: false, reason: "Incomplete consent token" };
  }

  if (now >= token.expiresAt) {
    return { valid: false, reason: "Consent token expired" };
  }

  if (now < token.issuedAt) {
    return { valid: false, reason: "Consent token not yet valid" };
  }

  const { signature, ...unsigned } = token;
  const expected = await signCaregiverConsentPayload(
    caregiverConsentCanonicalPayload(unsigned),
    options.signingSecret,
  );

  if (expected.length !== signature.length) {
    return { valid: false, reason: "Invalid consent signature" };
  }

  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  if (diff !== 0) {
    return { valid: false, reason: "Invalid consent signature" };
  }

  const session: CaregiverSession = {
    sessionId: `caregiver_${token.tokenId}`,
    mode: "caregiverMonitoring",
    caregiverId: token.caregiverId,
    subjectAccountId: token.subjectAccountId,
    permissions: token.permissions,
    tokenId: token.tokenId,
    startedAt: now,
    expiresAt: token.expiresAt,
    validatedAt: now,
  };

  return { valid: true, session };
}
