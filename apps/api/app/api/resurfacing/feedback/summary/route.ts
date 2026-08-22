import { NextResponse } from "next/server";

import { resolveApiGuardContext } from "@/lib/server/api-guard";
import { apiErrorResponse } from "@/lib/server/api-error-response";
import { fetchResurfacingFeedbackSummary } from "@/lib/server/resurfacing-feedback-store";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const ctx = await resolveApiGuardContext(request);
  if (!ctx?.userId) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "resurfacing/feedback/summary",
    });
  }

  const summary = await fetchResurfacingFeedbackSummary(ctx.userId);
  return NextResponse.json({ summary, at: new Date().toISOString() });
}
