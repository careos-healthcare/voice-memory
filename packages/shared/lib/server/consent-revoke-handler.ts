import "server-only";

import {
  authorizeConsentRevocation,
  type PresentedConsentToken,
} from "@/lib/server/consent-revoke-authorization";
import {
  ConsentRevocationStoreUnavailableError,
  isConsentGrantKind,
  recordConsentRevocation,
  type ConsentGrantKind,
} from "@/lib/server/consent-revocation-store";
import { logServerEvent } from "@/lib/server/structured-log";
import { updateRelationshipConsentStatus } from "@/lib/server/user-relationships-store";
import type { CaregiverPermissions, MonitoringConsentToken } from "@/types/caregiver";
import type { CoachConsentToken } from "@/types/coach-client-relationship";
import type { ArchiveInsightKind } from "@/types/insights";

/**
 * The body of `POST /api/coach/consent/revoke`, minus the HTTP plumbing, so the
 * decision logic can be tested without standing up a route.
 */

const MAX_REASON_LENGTH = 200;

export type ConsentRevokeFailureCode =
  | "INVALID_TOKEN_ID"
  | "FORBIDDEN"
  | "CONSENT_REVOKE_FAILED";

export type ConsentRevokeResult =
  | {
      ok: true;
      tokenId: string;
      grantKind: ConsentGrantKind;
      revokedAt: string;
      alreadyRevoked: boolean;
    }
  | { ok: false; code: ConsentRevokeFailureCode };

/** `"caregiver"` is the legacy alias the mobile client sent before this route existed. */
export function parseConsentGrantKind(raw: unknown): ConsentGrantKind {
  if (raw === "caregiver" || raw === "caregiverMonitoring") {
    return "caregiverMonitoring";
  }
  if (raw === "coach" || raw === "coachClient") return "coachClient";
  return "coachClient";
}

function parseCaregiverPermissions(raw: unknown): CaregiverPermissions | null {
  if (!raw || typeof raw !== "object") return null;
  const input = raw as Record<string, unknown>;
  if (!Array.isArray(input.evidenceStreamIds)) return null;
  return {
    evidenceStreamIds: input.evidenceStreamIds
      .map((value) => (typeof value === "string" ? value : null))
      .filter((value): value is string => value != null),
    reviewSummaries: input.reviewSummaries === true,
    thresholdAlerts: input.thresholdAlerts === true,
  };
}

function parsePresentedCaregiverToken(raw: unknown): MonitoringConsentToken | null {
  if (!raw || typeof raw !== "object") return null;
  const input = raw as Record<string, unknown>;
  const permissions = parseCaregiverPermissions(input.permissions);
  if (!permissions) return null;

  return {
    tokenId: String(input.tokenId ?? ""),
    subjectAccountId: String(input.subjectAccountId ?? ""),
    caregiverId: String(input.caregiverId ?? ""),
    permissions,
    issuedAt: String(input.issuedAt ?? ""),
    expiresAt: String(input.expiresAt ?? ""),
    policyVersion:
      typeof input.policyVersion === "number" ? input.policyVersion : 1,
    signature: String(input.signature ?? ""),
  };
}

function parsePresentedCoachToken(raw: unknown): CoachConsentToken | null {
  if (!raw || typeof raw !== "object") return null;
  const input = raw as Record<string, unknown>;
  const permissionsRaw = input.permissions;
  if (!permissionsRaw || typeof permissionsRaw !== "object") return null;
  const permissions = permissionsRaw as Record<string, unknown>;
  if (!Array.isArray(permissions.insightKinds)) return null;

  return {
    tokenId: String(input.tokenId ?? ""),
    relationshipId: String(input.relationshipId ?? ""),
    clientAccountId: String(input.clientAccountId ?? ""),
    coachId: String(input.coachId ?? ""),
    permissions: {
      factLedger: permissions.factLedger === true,
      confidenceBandedInsights: permissions.confidenceBandedInsights !== false,
      insightKinds: permissions.insightKinds.map(
        (value) => String(value) as ArchiveInsightKind,
      ),
    },
    issuedAt: String(input.issuedAt ?? ""),
    expiresAt: String(input.expiresAt ?? ""),
    policyVersion:
      typeof input.policyVersion === "number" ? input.policyVersion : 1,
    clientAffirmationHash: String(input.clientAffirmationHash ?? ""),
    signature: String(input.signature ?? ""),
  };
}

/**
 * Falls back to the other grant kind when the token does not parse as the one
 * the caller declared. A mislabelled `consentDomain` should not be the reason
 * someone cannot end access; the signature check still binds the token to its
 * kind, so nothing is accepted that would not have been accepted anyway.
 */
export function parsePresentedConsentToken(
  grantKind: ConsentGrantKind,
  raw: unknown,
): PresentedConsentToken | null {
  if (raw == null) return null;

  const asCaregiver = parsePresentedCaregiverToken(raw);
  const asCoach = parsePresentedCoachToken(raw);

  if (grantKind === "caregiverMonitoring") {
    if (asCaregiver) return { grantKind: "caregiverMonitoring", token: asCaregiver };
    return asCoach ? { grantKind: "coachClient", token: asCoach } : null;
  }
  if (asCoach) return { grantKind: "coachClient", token: asCoach };
  return asCaregiver
    ? { grantKind: "caregiverMonitoring", token: asCaregiver }
    : null;
}

function parseReason(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, MAX_REASON_LENGTH);
}

/**
 * Records a revocation on behalf of the authenticated account.
 *
 * Idempotent: revoking a token that is already revoked, already expired, or
 * unknown-but-provably-owned all succeed. Nothing here reports an error that
 * would leave a user unable to end someone's access — the only refusals are
 * "you are not the owner of this grant" and "the store is unreachable", and the
 * second is retryable.
 */
export async function handleConsentRevocation(input: {
  sessionUserId: string;
  body: Record<string, unknown>;
  now?: Date;
}): Promise<ConsentRevokeResult> {
  const tokenId =
    typeof input.body.tokenId === "string" ? input.body.tokenId.trim() : "";
  if (!tokenId) return { ok: false, code: "INVALID_TOKEN_ID" };

  const grantKind = isConsentGrantKind(input.body.consentDomain)
    ? input.body.consentDomain
    : parseConsentGrantKind(input.body.consentDomain);
  const presentedToken = parsePresentedConsentToken(grantKind, input.body.token);
  const reason = parseReason(input.body.reason);

  try {
    const authorization = await authorizeConsentRevocation({
      sessionUserId: input.sessionUserId,
      tokenId,
      grantKind,
      presentedToken,
    });

    if (!authorization.allowed) {
      logServerEvent("auth_failure", {
        route: "coach/consent/revoke",
        errorCode: "FORBIDDEN",
        internalCategory: "forbidden",
        denialCode: authorization.denialCode,
        consentDomain: grantKind,
      });
      return { ok: false, code: "FORBIDDEN" };
    }

    const identity = authorization.identity;
    const outcome = await recordConsentRevocation({
      tokenId,
      grantKind: identity.grantKind,
      subjectAccountId: identity.subjectAccountId,
      partyId: identity.partyId,
      relationshipId: identity.relationshipId,
      issuedAt: identity.issuedAt,
      expiresAt: identity.expiresAt,
      revokedBy: input.sessionUserId,
      revocationReason: reason,
      now: input.now,
    });

    // Best effort, and deliberately after the revocation is durable: the
    // relationship row is a convenience view, the revocation list is the gate.
    if (identity.grantKind === "coachClient" && identity.relationshipId) {
      try {
        await updateRelationshipConsentStatus(
          identity.relationshipId,
          "revoked",
          input.sessionUserId,
        );
      } catch (error) {
        logServerEvent("api_error", {
          route: "coach/consent/revoke",
          errorCode: "RELATIONSHIP_STATUS_UPDATE_FAILED",
          internalCategory: "internal_error",
          message: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return {
      ok: true,
      tokenId,
      grantKind: identity.grantKind,
      revokedAt: outcome.revokedAt,
      alreadyRevoked: outcome.alreadyRevoked,
    };
  } catch (error) {
    logServerEvent("api_error", {
      route: "coach/consent/revoke",
      errorCode: "CONSENT_REVOKE_FAILED",
      internalCategory: "internal_error",
      consentDomain: grantKind,
      storeUnavailable: error instanceof ConsentRevocationStoreUnavailableError,
      message: error instanceof Error ? error.message : String(error),
    });
    return { ok: false, code: "CONSENT_REVOKE_FAILED" };
  }
}
