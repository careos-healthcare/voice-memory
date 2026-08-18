import { NextResponse } from "next/server";

import type { ResurfacingMetricName } from "@/lib/resurfacing/resurfacing-metrics";
import { resolveApiGuardContext } from "@/lib/server/api-guard";
import { apiErrorResponse } from "@/lib/server/api-error-response";
import { hasFounderDebugCookie, isFounderEmail } from "@/lib/server/founder-access";
import {
  aggregateResurfacingMetrics,
  recordResurfacingEvent,
} from "@/lib/server/resurfacing-metrics-store";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

const ALLOWED: ResurfacingMetricName[] = [
  "callback_shown",
  "callback_dismissed",
  "callback_fit_clicked",
  "not_me_clicked",
  "wrong_topic_clicked",
  "wrong_person_clicked",
  "too_intense_clicked",
  "too_vague_clicked",
  "already_know_clicked",
  "show_less_like_this_clicked",
  "related_memory_opened",
  "voice_replayed_after_callback",
  "rerecord_within_10min",
  "return_next_day_after_callback",
  "callback_suppressed_no_evidence",
  "callback_suppressed_stale",
  "callback_suppressed_feedback",
  "callback_suppressed_ambiguity",
  "low_confidence_suppressed",
  "generic_phrase_shown",
  "quote_backed_shown",
];

export async function POST(request: Request) {
  const ctx = await resolveApiGuardContext(request);
  if (!ctx) {
    return apiErrorResponse({
      code: "CAPTURE_AUTH_REQUIRED",
      route: "metrics/resurfacing",
      internalCategory: "unauthenticated",
    });
  }

  let body: {
    event?: ResurfacingMetricName;
    confidence?: number;
    phraseKey?: string;
  };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "metrics/resurfacing",
      internalCategory: "validation",
    });
  }

  if (!body.event || !ALLOWED.includes(body.event)) {
    return apiErrorResponse({ code: "CAPTURE_INVALID_EVENT", route: "metrics/resurfacing" });
  }

  await recordResurfacingEvent({
    subjectKey: ctx.subject,
    userId: ctx.userId,
    eventName: body.event,
    confidence: body.confidence,
    phraseKey: body.phraseKey,
  });

  return NextResponse.json({ ok: true });
}

/** Founder-only aggregate — requires session + founder email or debug cookie. */
export async function GET(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "metrics/resurfacing",
    });
  }

  const founderCookie = await hasFounderDebugCookie();
  if (!founderCookie && !isFounderEmail(session.email)) {
    return apiErrorResponse({
      code: "FORBIDDEN",
      route: "metrics/resurfacing",
      internalCategory: "forbidden",
    });
  }

  const subject = new URL(request.url).searchParams.get("subject");
  const metrics = await aggregateResurfacingMetrics(subject ?? undefined);
  return NextResponse.json({ metrics, at: new Date().toISOString() });
}
