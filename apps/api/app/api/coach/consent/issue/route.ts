import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { issueServerCoachConsentToken } from "@/lib/server/coach-consent-crypto";
import { issueServerCaregiverConsentToken } from "@/lib/server/caregiver-consent-crypto";
import { upsertUserRelationship } from "@/lib/server/user-relationships-store";
import { getServerSession } from "@/lib/server/session";
import type { ArchiveInsightKind } from "@/types/insights";
import type { CoachSharingPermissions } from "@/types/coach-client-relationship";
import { COACH_SESSION_PLANNING_INSIGHT_KINDS } from "@/types/coach-client-relationship";
import type { CaregiverPermissions } from "@/types/caregiver";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function parsePermissions(raw: unknown): CoachSharingPermissions | null {
  if (!raw || typeof raw !== "object") return null;
  const input = raw as Record<string, unknown>;
  const insightKindsRaw = input.insightKinds;
  if (!Array.isArray(insightKindsRaw)) return null;

  const allowed = new Set<string>(COACH_SESSION_PLANNING_INSIGHT_KINDS);
  const insightKinds = insightKindsRaw
    .map((value) => (typeof value === "string" ? value : null))
    .filter(
      (value): value is ArchiveInsightKind =>
        value != null && allowed.has(value),
    );

  return {
    factLedger: input.factLedger === true,
    confidenceBandedInsights: input.confidenceBandedInsights !== false,
    insightKinds:
      insightKinds.length > 0
        ? insightKinds
        : (["belief", "blindSpot", "contradiction"] as const),
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

function isCaregiverConsentDomain(body: Record<string, unknown>): boolean {
  const domain = body.consentDomain;
  return domain === "caregiverMonitoring" || domain === "caregiver";
}

/** Issue an HMAC-signed consent token for the authenticated account. */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "coach/consent/issue",
    });
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "coach/consent/issue",
      internalCategory: "validation",
    });
  }

  if (isCaregiverConsentDomain(body)) {
    const caregiverId =
      typeof body.caregiverId === "string" ? body.caregiverId.trim() : "";
    const permissions = parseCaregiverPermissions(body.permissions);

    if (!caregiverId) {
      return apiErrorResponse({ code: "INVALID_CAREGIVER_ID", route: "coach/consent/issue" });
    }

    if (!permissions) {
      return apiErrorResponse({ code: "INVALID_PERMISSIONS", route: "coach/consent/issue" });
    }

    try {
      const token = await issueServerCaregiverConsentToken({
        tokenId: randomUUID(),
        subjectAccountId: session.userId,
        caregiverId,
        permissions,
      });

      return NextResponse.json({ ok: true, token });
    } catch (error) {
      return apiErrorFromException(error, {
        code: "CAREGIVER_CONSENT_ISSUE_FAILED",
        route: "coach/consent/issue",
        logEvent: "api_error",
      });
    }
  }

  const coachId = typeof body.coachId === "string" ? body.coachId.trim() : "";
  const clientAffirmationHash =
    typeof body.clientAffirmationHash === "string"
      ? body.clientAffirmationHash.trim()
      : "";
  const relationshipId =
    typeof body.relationshipId === "string" && body.relationshipId.trim()
      ? body.relationshipId.trim()
      : randomUUID();
  const permissions = parsePermissions(body.permissions);

  if (!coachId) {
    return apiErrorResponse({ code: "INVALID_COACH_ID", route: "coach/consent/issue" });
  }

  if (!clientAffirmationHash) {
    return apiErrorResponse({ code: "INVALID_AFFIRMATION", route: "coach/consent/issue" });
  }

  if (!permissions) {
    return apiErrorResponse({ code: "INVALID_PERMISSIONS", route: "coach/consent/issue" });
  }

  try {
    const token = await issueServerCoachConsentToken({
      tokenId: randomUUID(),
      relationshipId,
      clientAccountId: session.userId,
      coachId,
      permissions,
      clientAffirmationHash,
    });

    await upsertUserRelationship({
      id: relationshipId,
      clientId: session.userId,
      professionalId: coachId,
      relationshipType: "professional",
      consentStatus: "active",
      agreedScope: {
        factLedger: permissions.factLedger,
        confidenceBandedInsights: permissions.confidenceBandedInsights,
        insightKinds: permissions.insightKinds,
      },
      activeConsentTokenId: token.tokenId,
    });

    return NextResponse.json({ ok: true, token });
  } catch (error) {
    return apiErrorFromException(error, {
      code: "COACH_CONSENT_ISSUE_FAILED",
      route: "coach/consent/issue",
      logEvent: "api_error",
    });
  }
}
