import {
  ephemeralAiJson,
  logEphemeralAiFailure,
} from "@/lib/privacy/ephemeral-ai-response";
import { getOpenAIClient } from "@/lib/openai";
import { apiPayloadTooLarge, guardOpenAiRoute } from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import {
  authenticatedUserIdMismatchResponse,
} from "@/lib/server/revenuecat-entitlement-guard";
import {
  meterConfiguredOpenAiChatUsage,
  vendorRequestId,
} from "@/lib/server/unit-economics-meter";
import { buildHybridAiPromptContext } from "@/lib/ai/hybrid-ai-prompt-context";
import {
  parseWeeklyIntelligenceRequest,
  validateWeeklyIntelligenceResult,
} from "@/lib/weekly-intelligence/weekly-intelligence-contract";
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_BODY_BYTES = 300_000;
const SYSTEM_PROMPT = `You generate ArchiveMe Sunday Behavioral Intelligence.
Do not summarize what happened. Analyze behavioral CHANGE. Contrast this week's audio logs with previous weeks. Highlight where the user's behavior diverged from stated intentions, where emotional tone shifted, and what habits actually gained or lost momentum.
Return JSON { weekStart, weekEnd, deltas }. Every delta is { dimension, magnitude, nodeIds, conclusion }, where dimension is action_intent_ratio, emotional_velocity, habit_drift, relationship_dynamics, or identity_shift.
Every conclusion must use strict ExplainableConclusionV4 with confidence/confidencePercent, step-by-step reasoning, alternativeExplanation plus alternatives, uncertainty plus uncertaintyNote, and provenance schemaVersion 4 with promptVersion "archive-explainable-v2".
Every continuing or new theory must include a persistent theoryId and chronological evolutionHistory. Append a snapshot containing date, confidenceScore, exact triggeringEvidence, and deltaReasoning describing why confidence strengthened, weakened, or stayed unchanged.
Every delta MUST cite at least one exact quote from a baseline entry and one exact quote from a current-week entry. Include sourceEntryId/entryId, exactQuote/quote, UTF-16 offsets, confidenceScore, role, and optional audioTimestampMs. Quotes must be exact canonicalTranscript slices.
Use conditional, epistemically humble language. Never diagnose, infer hidden motives as facts, give advice, or claim causation.`;

export async function POST(request: Request) {
  let usageReservationId: string | undefined;
  try {
    const rawBody = await request.text();
    if (rawBody.length > MAX_BODY_BYTES) {
      return apiPayloadTooLarge("Weekly intelligence payload too large");
    }
    let body;
    try {
      body = parseWeeklyIntelligenceRequest(JSON.parse(rawBody));
    } catch (error) {
      return ephemeralAiJson(
        {
          error: error instanceof Error ? error.message : "Invalid request",
          code: "INVALID_REQUEST",
        },
        { status: 400 },
      );
    }
    const guard = await guardOpenAiRoute(request, "analyze", {
      transcriptChars: rawBody.length,
    });
    if (!guard.ok) return guard.response;
    usageReservationId = guard.ctx.monetization?.reservation?.reservationId;
    const authenticatedUserId =
      guard.ctx.via === "session" ? guard.ctx.userId : undefined;
    if (!authenticatedUserId) {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return ephemeralAiJson(
        { error: "Sign in required.", code: "AUTH_REQUIRED" },
        { status: 401 },
      );
    }
    const mismatch = authenticatedUserIdMismatchResponse(
      body.userId,
      authenticatedUserId,
    );
    if (mismatch) {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return mismatch;
    }
    const {
      negativeFewShotConstraints: correctionBlock,
      activeHypothesisContext,
      truthAnchorContext,
    } = await buildHybridAiPromptContext(
      authenticatedUserId,
      body.activeHypotheses,
      body.truthAnchors,
    );

    const model =
      process.env.VOICEMEMORY_ARCHIVE_SYNTHESIS_MODEL?.trim() || "gpt-4o-mini";
    const completion = await getOpenAIClient().chat.completions.create({
      model,
      store: false,
      response_format: { type: "json_object" },
      temperature: 0.2,
      messages: [
        {
          role: "system",
          content: `${SYSTEM_PROMPT}${correctionBlock ? `\n\n${correctionBlock}` : ""}${activeHypothesisContext ? `\n\n${activeHypothesisContext}` : ""}${truthAnchorContext ? `\n\n${truthAnchorContext}` : ""}`,
        },
        {
          role: "user",
          content: JSON.stringify({
            weekStart: body.weekStart,
            weekEnd: body.weekEnd,
            baselineWeekCount: body.baselineWeekCount,
            localDeltas: body.localDeltas,
            evidence: body.evidence,
          }),
        },
      ],
    });
    await meterConfiguredOpenAiChatUsage({
      operation: "weekly-intelligence-synthesis.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(completion),
      model,
      usage: completion.usage,
    });
    const content = completion.choices[0]?.message?.content;
    if (!content) throw new Error("WEEKLY_INTELLIGENCE_EMPTY");
    const validation = validateWeeklyIntelligenceResult(
      JSON.parse(content),
      body,
    );
    if (!validation.ok) {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return ephemeralAiJson(
        {
          error: "Weekly intelligence failed validation",
          code: "INVALID_MODEL_OUTPUT",
          errors: validation.errors,
        },
        { status: 422 },
      );
    }
    return ephemeralAiJson(validation.result);
  } catch (error) {
    if (usageReservationId) await releaseUsageReservation(usageReservationId);
    logEphemeralAiFailure("weekly-intelligence-synthesis", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return ephemeralAiJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
