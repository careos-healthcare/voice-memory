import {
  ephemeralAiJson,
  logEphemeralAiFailure,
} from "@/lib/privacy/ephemeral-ai-response";

import { guardOpenAiRoute } from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { PRODUCT_WEDGE_LINE } from "@/lib/product-copy";
import { getOpenAIClient } from "@/lib/openai";
import {
  meterOpenAiChatUsage,
  vendorRequestId,
} from "@/lib/server/unit-economics-meter";
import { validateExplainableConclusion } from "@/lib/explainability/validate-explainable-conclusion";
import type {
  WeeklyReflectionPayload,
  WeeklyReflectionResponse,
} from "@/types/weekly";
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
const NextResponse = { json: ephemeralAiJson };

const SYSTEM_PROMPT = `You detect weekly language patterns for ArchiveMe — ${PRODUCT_WEDGE_LINE} NOT therapy.
Given weekly aggregates and canonical transcript sources, produce one strictly evidenced conclusion.

Rules:
- Speak directly to the user ("you")
- Do not claim repetition unless exact supporting citations prove it
- Reference dominant emotions, themes, concerns, and week-over-week shift when provided
- Be specific but never clinical; do not diagnose or make absolute psychological claims. Frame conclusions as recurring themes supported by the cited recordings.
- NO advice, NO "you should", NO motivational encouragement, NO intentions for next week
- Never mention being an AI
- Evidence quote must exactly equal canonicalTranscript.slice(startUtf16, endUtf16), using inclusive/exclusive JavaScript UTF-16 offsets and a listed entryId. No fuzzy matching.
- confidencePercent is an integer. One support caps it at 70, two at 85, three or more at 95; subtract 15 per counter citation.
- Include non-empty reasoning, meaningful uncertainty, alternativeExplanation, and compatibility aliases where confidence equals confidencePercent, uncertainty equals uncertaintyNote, and alternatives[0] equals alternativeExplanation.
- provenance is { generatedBy: "model", generatedAt, schemaVersion: 4, model: "gpt-4o-mini", promptVersion: "weekly-explainable-v2" }.
- Return JSON only: { "explainableConclusion": { "id", "statement", "confidence", "confidencePercent", "reasoning": [string], "uncertainty", "uncertaintyNote", "evidence": [{ "sourceEntryId", "exactQuote", "audioTimestampMs"?, "confidenceScore", "entryId", "quote", "startUtf16", "endUtf16", "role" }], "alternativeExplanation": { "statement", "reason" }, "alternatives": [{ "statement", "reason" }], "provenance" } }`;

function canonicalSources(
  body: WeeklyReflectionPayload,
): Map<string, string> | null {
  if (
    !Array.isArray(body.citationSources) ||
    body.citationSources.length === 0
  ) {
    return null;
  }
  const sources = new Map<string, string>();
  for (const source of body.citationSources) {
    if (
      !source ||
      typeof source.entryId !== "string" ||
      !source.entryId.trim() ||
      typeof source.canonicalTranscript !== "string" ||
      !source.canonicalTranscript.trim() ||
      sources.has(source.entryId)
    ) {
      return null;
    }
    sources.set(source.entryId, source.canonicalTranscript);
  }
  return sources;
}

export async function POST(request: Request) {
  let usageReservationId: string | undefined;
  try {
    const body = (await request.json()) as WeeklyReflectionPayload;

    if (!body.weekEndingKey || body.entryCount === 0) {
      return NextResponse.json(
        { error: "No entries in the current week window" },
        { status: 400 },
      );
    }
    const sources = canonicalSources(body);
    if (!sources) {
      return NextResponse.json(
        {
          unavailable: true,
          code: "VERIFIABLE_SOURCES_REQUIRED",
          error:
            "AI weekly reflection requires canonical transcript citation sources.",
        },
        { status: 422 },
      );
    }

    const guard = await guardOpenAiRoute(request, "analyze");
    if (!guard.ok) return guard.response;
    usageReservationId = guard.ctx.monetization?.reservation?.reservationId;

    const openai = getOpenAIClient();

    const userContent = `Weekly intelligence aggregates (last 7 days vs prior 7 days):

This week (${body.weekEndingKey} window):
- Entries: ${body.entryCount}
- Dominant emotions: ${body.dominantEmotions.join(", ") || "none"}
- Recurring themes: ${body.recurringThemes.join(", ") || "none"}
- Repeated threads: ${body.repeatedConcerns.join("; ") || "none"}
- People/entities mentioned: ${body.repeatedEntities.join(", ") || "none"}
- Average emotional intensity: ${body.avgIntensityThisWeek ?? "n/a"}/10
- Emotional shift vs last week: ${body.emotionalShiftLabel}
- Pattern observations: ${body.observationHighlights.join(" | ") || "none"}

Last week:
- Entries: ${body.lastWeekEntryCount}
- Average intensity: ${body.avgIntensityLastWeek ?? "n/a"}/10

Canonical citation sources:
${JSON.stringify(body.citationSources)}

Write one explainable weekly conclusion.`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      store: false,
      response_format: { type: "json_object" },
      temperature: 0.75,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userContent },
      ],
    });
    await meterOpenAiChatUsage({
      operation: "weekly-reflection.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(
        completion,
        request.headers.get("x-vm-idempotency-key"),
      ),
      resource: "openai.gpt-4o-mini",
      modelDimension: "gpt-4o-mini",
      usage: completion.usage,
    });

    const content = completion.choices[0]?.message?.content;
    if (!content) {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return NextResponse.json(
        { error: "No summary returned from model" },
        { status: 502 },
      );
    }

    let parsed: { explainableConclusion?: unknown };
    try {
      parsed = JSON.parse(content) as { explainableConclusion?: unknown };
    } catch {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return NextResponse.json(
        {
          unavailable: true,
          code: "CONCLUSION_VALIDATION_FAILED",
          error: "Weekly reflection failed evidence checks.",
        },
        { status: 422 },
      );
    }
    const validation = validateExplainableConclusion(
      parsed.explainableConclusion,
      sources,
      "explainableConclusion",
    );
    if (
      !validation.ok ||
      validation.conclusion?.provenance.generatedBy !== "model"
    ) {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return NextResponse.json(
        {
          unavailable: true,
          code: "CONCLUSION_VALIDATION_FAILED",
          error: "Weekly reflection failed evidence checks.",
        },
        { status: 422 },
      );
    }
    const response: WeeklyReflectionResponse = {
      summary: validation.conclusion.statement,
      explainableConclusion: validation.conclusion,
    };
    return NextResponse.json(response);
  } catch (error) {
    if (usageReservationId) await releaseUsageReservation(usageReservationId);
    logEphemeralAiFailure("weekly-reflection", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return NextResponse.json(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
