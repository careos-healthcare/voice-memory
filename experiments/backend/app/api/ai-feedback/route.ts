import { NextResponse } from "next/server";

import { parseAiAccuracyFeedback } from "@/lib/ai-feedback/ai-feedback-contract";
import { resolveApiGuardContext } from "@/lib/server/api-guard";
import {
  aiAccuracyMetrics,
  upsertAiAccuracyFeedback,
} from "@/lib/server/ai-feedback-store";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const ctx = await resolveApiGuardContext(request);
  if (!ctx?.userId) {
    return NextResponse.json(
      { error: "Sign in required for AI feedback.", code: "FEEDBACK_AUTH_REQUIRED" },
      { status: 401 },
    );
  }
  try {
    const feedback = parseAiAccuracyFeedback(await request.json());
    await upsertAiAccuracyFeedback(ctx.userId, feedback);
    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Invalid feedback",
        code: "INVALID_AI_FEEDBACK",
      },
      { status: 400 },
    );
  }
}

export async function GET(request: Request) {
  const ctx = await resolveApiGuardContext(request);
  if (!ctx?.userId) {
    return NextResponse.json(
      { error: "Sign in required.", code: "FEEDBACK_AUTH_REQUIRED" },
      { status: 401 },
    );
  }
  return NextResponse.json({ metrics: await aiAccuracyMetrics(ctx.userId) });
}
