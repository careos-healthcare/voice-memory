import { NextResponse } from "next/server";

import { resolveApiGuardContext } from "@/lib/server/api-guard";
import { fetchResurfacingFeedbackSummary } from "@/lib/server/resurfacing-feedback-store";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const ctx = await resolveApiGuardContext(request);
  if (!ctx?.userId) {
    return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  }

  const summary = await fetchResurfacingFeedbackSummary(ctx.userId);
  return NextResponse.json({ summary, at: new Date().toISOString() });
}
