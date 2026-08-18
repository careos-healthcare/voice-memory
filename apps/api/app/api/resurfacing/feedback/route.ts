import { NextResponse } from "next/server";

import {
  SERVER_FEEDBACK_ALLOWLIST,
  FEEDBACK_WEIGHT_BY_KIND,
} from "@/lib/resurfacing/resurfacing-feedback-summary";
import type { ResurfacingFeedbackKind } from "@/lib/resurfacing/resurfacing-feedback";
import { resolveApiGuardContext } from "@/lib/server/api-guard";
import { apiErrorResponse } from "@/lib/server/api-error-response";
import {
  evidenceClusterHash,
  feedbackWeightForKind,
  hashPersonKeyForServer,
  hashPhraseKeyForServer,
  hashTopicKeyForServer,
  insertResurfacingFeedback,
} from "@/lib/server/resurfacing-feedback-store";

export const runtime = "nodejs";

const BLOCKED_BODY_KEYS = [
  "quote",
  "transcript",
  "reflection",
  "journal",
  "text",
  "raw",
  "entry",
] as const;

export async function POST(request: Request) {
  const ctx = await resolveApiGuardContext(request);
  if (!ctx?.userId) {
    return apiErrorResponse({
      code: "FEEDBACK_AUTH_REQUIRED",
      route: "resurfacing/feedback",
      internalCategory: "unauthenticated",
    });
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiErrorResponse({
      code: "FEEDBACK_INVALID_BODY",
      route: "resurfacing/feedback",
      internalCategory: "validation",
    });
  }

  for (const key of BLOCKED_BODY_KEYS) {
    if (key in body) {
      return apiErrorResponse({ code: "FEEDBACK_RAW_REJECTED", route: "resurfacing/feedback" });
    }
  }

  const feedbackType = body.feedbackType as ResurfacingFeedbackKind | undefined;
  const phraseKey = typeof body.phraseKey === "string" ? body.phraseKey.trim() : "";
  const topicKey = typeof body.topicKey === "string" ? body.topicKey.trim() : "";
  const personKey = typeof body.personKey === "string" ? body.personKey.trim() : "";
  const surface = typeof body.surface === "string" ? body.surface.slice(0, 32) : "callback";

  if (!feedbackType || !SERVER_FEEDBACK_ALLOWLIST.includes(feedbackType)) {
    return apiErrorResponse({ code: "FEEDBACK_INVALID_TYPE", route: "resurfacing/feedback" });
  }
  if (!phraseKey || phraseKey.length > 80) {
    return apiErrorResponse({ code: "FEEDBACK_INVALID_PHRASE", route: "resurfacing/feedback" });
  }

  const phraseKeyHash = hashPhraseKeyForServer(phraseKey);
  const topicHash = topicKey ? hashTopicKeyForServer(topicKey) : undefined;
  const personHash = personKey ? hashPersonKeyForServer(personKey) : undefined;
  const clusterHash = evidenceClusterHash({
    phraseKeyHash,
    topicHash,
    personHash,
  });

  await insertResurfacingFeedback({
    userId: ctx.userId,
    feedbackType,
    phraseKeyHash,
    feedbackWeight: feedbackWeightForKind(feedbackType),
    evidenceClusterHash: clusterHash || undefined,
    topicHash,
    personHash,
    metadata: { surface, weightKind: FEEDBACK_WEIGHT_BY_KIND[feedbackType] },
  });

  console.info(
    "[resurfacing-feedback]",
    JSON.stringify({
      userId: ctx.userId.slice(0, 8),
      feedbackType,
      phraseKeyHash,
      topicHash: topicHash ?? null,
      personHash: personHash ?? null,
    }),
  );

  return NextResponse.json({ ok: true });
}
