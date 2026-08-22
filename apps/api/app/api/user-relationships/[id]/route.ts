import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { updateRelationshipConsentStatus } from "@/lib/server/user-relationships-store";
import { getServerSession } from "@/lib/server/session";
import type { ConsentStatus } from "@/types/user-relationship";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function parseConsentStatus(raw: unknown): ConsentStatus | null {
  if (raw === "pending" || raw === "active" || raw === "revoked") return raw;
  return null;
}

/** Update consent status for a relationship the caller participates in. */
export async function PATCH(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await getServerSession();
  if (!session?.userId) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "user-relationships/[id]",
    });
  }

  const { id } = await context.params;
  if (!id?.trim()) {
    return apiErrorResponse({ code: "INVALID_ID", route: "user-relationships/[id]" });
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "user-relationships/[id]",
      internalCategory: "validation",
    });
  }

  const consentStatus = parseConsentStatus(body.consentStatus);
  if (!consentStatus) {
    return apiErrorResponse({ code: "INVALID_CONSENT_STATUS", route: "user-relationships/[id]" });
  }

  try {
    const relationship = await updateRelationshipConsentStatus(
      id.trim(),
      consentStatus,
      session.userId,
    );
    if (!relationship) {
      return apiErrorResponse({ code: "NOT_FOUND", route: "user-relationships/[id]" });
    }
    return NextResponse.json({ ok: true, relationship });
  } catch (error) {
    console.error("PATCH /api/user-relationships/[id] failed", error);
    return apiErrorFromException(error, {
      code: "RELATIONSHIPS_UPDATE_FAILED",
      route: "user-relationships/[id]",
      logEvent: "api_error",
    });
  }
}
