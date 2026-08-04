import {
  ephemeralAiJson,
  logEphemeralAiFailure,
} from "@/lib/privacy/ephemeral-ai-response";
import {
  parseDashboardSynthesisRequest,
  validateDashboardSynthesisResult,
} from "@/lib/dashboard-synthesis/dashboard-synthesis-contract";
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
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_BODY_BYTES = 250_000;
const SYSTEM_PROMPT = `Create a multi-horizon Life Dashboard synthesis from supplied local metrics and canonical evidence only.
Use epistemically humble, conditional pattern language. Never diagnose, assert hidden motives, or present predictions as certain.
Return JSON { horizon, identity, goals, predictions }. identity is null or one ExplainableConclusionV4; goals and predictions are arrays of ExplainableConclusionV4.
Every conclusion must include confidence/confidencePercent, chronological exact-quote evidence with sourceEntryId/entryId, exactQuote/quote, UTF-16 offsets, confidenceScore, role and optional audioTimestampMs, step-by-step reasoning, alternativeExplanation plus alternatives, uncertainty plus uncertaintyNote, and provenance schemaVersion 4 with promptVersion "archive-explainable-v2".
For a continued or newly synthesized theory, include a persistent theoryId and evolutionHistory. Append a ConfidenceSnapshot with date, confidenceScore, the exact triggeringEvidence citation, and deltaReasoning explaining the confidence change.
Copy every quote exactly from the matching canonicalTranscript. Predictions must explicitly state their conditional nature.`;

export async function POST(request: Request) {
  let usageReservationId: string | undefined;
  try {
    const rawBody = await request.text();
    if (rawBody.length > MAX_BODY_BYTES) {
      return apiPayloadTooLarge("Dashboard synthesis payload too large");
    }
    let body;
    try {
      body = parseDashboardSynthesisRequest(JSON.parse(rawBody));
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
      temperature: 0.25,
      messages: [
        {
          role: "system",
          content: `${SYSTEM_PROMPT}${correctionBlock ? `\n\n${correctionBlock}` : ""}${activeHypothesisContext ? `\n\n${activeHypothesisContext}` : ""}${truthAnchorContext ? `\n\n${truthAnchorContext}` : ""}`,
        },
        {
          role: "user",
          content: JSON.stringify({
            horizon: body.horizon,
            localMetrics: body.localMetrics,
            evidence: body.evidence,
          }),
        },
      ],
    });
    await meterConfiguredOpenAiChatUsage({
      operation: "dashboard-synthesis.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(completion),
      model,
      usage: completion.usage,
    });
    const content = completion.choices[0]?.message?.content;
    if (!content) throw new Error("DASHBOARD_SYNTHESIS_EMPTY");
    const validation = validateDashboardSynthesisResult(
      JSON.parse(content),
      body,
    );
    if (!validation.ok) {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return ephemeralAiJson(
        {
          error: "Dashboard synthesis failed validation",
          code: "INVALID_MODEL_OUTPUT",
          errors: validation.errors,
        },
        { status: 422 },
      );
    }
    return ephemeralAiJson(validation.result);
  } catch (error) {
    if (usageReservationId) await releaseUsageReservation(usageReservationId);
    logEphemeralAiFailure("dashboard-synthesis", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return ephemeralAiJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
