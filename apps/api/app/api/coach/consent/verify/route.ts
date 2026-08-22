import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { verifyServerCoachConsentToken } from "@/lib/server/coach-consent-crypto";
import { verifyServerCaregiverConsentToken } from "@/lib/server/caregiver-consent-crypto";
import { getServerSession } from "@/lib/server/session";
import type { ArchiveInsightKind } from "@/types/insights";
import type { CoachConsentToken } from "@/types/coach-client-relationship";
import type {
  CaregiverPermissions,
  MonitoringConsentToken,
} from "@/types/caregiver";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function parseToken(raw: unknown): CoachConsentToken | null {
  if (!raw || typeof raw !== "object") return null;
  const input = raw as Record<string, unknown>;
  const permissionsRaw = input.permissions;
  if (!permissionsRaw || typeof permissionsRaw !== "object") return null;
  const permissions = permissionsRaw as Record<string, unknown>;
  const insightKinds = permissions.insightKinds;
  if (!Array.isArray(insightKinds)) return null;

  return {
    tokenId: String(input.tokenId ?? ""),
    relationshipId: String(input.relationshipId ?? ""),
    clientAccountId: String(input.clientAccountId ?? ""),
    coachId: String(input.coachId ?? ""),
    permissions: {
      factLedger: permissions.factLedger === true,
      confidenceBandedInsights: permissions.confidenceBandedInsights !== false,
      insightKinds: insightKinds.map(
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

function parseCaregiverPermissions(raw: unknown): CaregiverPermissions | null {
  if (!raw || typeof raw !== "object") return null;
  const input = raw as Record<string, unknown>;
  const streamsRaw = input.evidenceStreamIds;
  if (!Array.isArray(streamsRaw)) return null;

  return {
    evidenceStreamIds: streamsRaw
      .map((value) => (typeof value === "string" ? value : null))
      .filter((value): value is string => value != null),
    reviewSummaries: input.reviewSummaries === true,
    thresholdAlerts: input.thresholdAlerts === true,
  };
}

function parseCaregiverToken(raw: unknown): MonitoringConsentToken | null {
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

function isCaregiverConsentDomain(body: Record<string, unknown>): boolean {
  const domain = body.consentDomain;
  return domain === "caregiverMonitoring" || domain === "caregiver";
}

/** Verify a server-signed consent token for the authenticated account. */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "coach/consent/verify",
    });
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "coach/consent/verify",
      internalCategory: "validation",
    });
  }

  if (isCaregiverConsentDomain(body)) {
    const caregiverToken = parseCaregiverToken(body.token);
    if (!caregiverToken) {
      return apiErrorResponse({ code: "INVALID_TOKEN", route: "coach/consent/verify" });
    }

    if (
      caregiverToken.subjectAccountId &&
      caregiverToken.subjectAccountId !== session.userId &&
      caregiverToken.caregiverId !== session.userId
    ) {
      return apiErrorResponse({
        code: "FORBIDDEN",
        route: "coach/consent/verify",
        internalCategory: "forbidden",
      });
    }

    try {
      const result = await verifyServerCaregiverConsentToken(caregiverToken);
      return NextResponse.json(result);
    } catch (error) {
      return apiErrorFromException(error, {
        code: "CAREGIVER_CONSENT_VERIFY_FAILED",
        route: "coach/consent/verify",
        logEvent: "api_error",
      });
    }
  }

  const token = parseToken(body.token);
  if (!token) {
    return apiErrorResponse({ code: "INVALID_TOKEN", route: "coach/consent/verify" });
  }

  if (
    token.clientAccountId &&
    token.clientAccountId !== session.userId &&
    token.coachId !== session.userId
  ) {
    return apiErrorResponse({
      code: "FORBIDDEN",
      route: "coach/consent/verify",
      internalCategory: "forbidden",
    });
  }

  try {
    const result = await verifyServerCoachConsentToken(token);
    return NextResponse.json(result);
  } catch (error) {
    return apiErrorFromException(error, {
      code: "COACH_CONSENT_VERIFY_FAILED",
      route: "coach/consent/verify",
      logEvent: "api_error",
    });
  }
}
