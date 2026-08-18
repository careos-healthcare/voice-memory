import { NextResponse } from "next/server";

import {
  insertInsightCorrection,
  isEvidenceInsightCorrectionReason,
} from "@/lib/insights/corrections-store";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "insights/corrections",
      });
    }

    let body: { insightId?: string; reason?: string };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "insights/corrections",
        internalCategory: "validation",
      });
    }

    const insightId = body.insightId?.trim() ?? "";
    const reason = body.reason?.trim() ?? "";

    if (!insightId) {
      return apiErrorResponse({ code: "INSIGHT_ID_REQUIRED", route: "insights/corrections" });
    }
    if (!isEvidenceInsightCorrectionReason(reason)) {
      return apiErrorResponse({ code: "INVALID_CORRECTION_REASON", route: "insights/corrections" });
    }

    await insertInsightCorrection({
      userId: session.userId,
      insightId,
      reason,
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("insights/corrections failed", error);
    return apiErrorFromException(error, {
      code: "INSIGHT_CORRECTION_FAILED",
      route: "insights/corrections",
      logEvent: "api_error",
    });
  }
}
