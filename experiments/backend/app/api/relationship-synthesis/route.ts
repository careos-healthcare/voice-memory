import {
  ephemeralAiJson,
  logEphemeralAiFailure,
} from "@/lib/privacy/ephemeral-ai-response";
import { validateExplainableConclusion } from "@/lib/explainability/validate-explainable-conclusion";
import { parseActiveHypotheses } from "@/lib/explainability/hypothesis-evolution-contract";
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
import type {
  RelationshipSynthesisRequest,
  RelationshipSynthesisResult,
} from "@/types/relationship-synthesis";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_BODY_BYTES = 200_000;
const SYSTEM_PROMPT = `You synthesize longitudinal relationship change from cited interactions only.
Use epistemically humble, pattern-based language. Never diagnose, infer motives as facts, or claim unrecorded context.
Return JSON { personNodeId, changeOverTime }, where changeOverTime is one ExplainableConclusionV4.
It must contain confidence/confidencePercent, chronological exact-quote evidence with sourceEntryId/entryId, exactQuote/quote, UTF-16 offsets, confidenceScore and role, step-by-step reasoning, alternativeExplanation plus alternatives, uncertainty plus uncertaintyNote, and provenance schemaVersion 4 with promptVersion "archive-explainable-v2".
Include a persistent theoryId and chronological evolutionHistory. Append one snapshot with date, confidenceScore, exact triggeringEvidence, and deltaReasoning for the shift.
Every quote must be an exact slice of the matching canonicalTranscript.`;

export async function POST(request: Request) {
  let usageReservationId: string | undefined;
  try {
    const rawBody = await request.text();
    if (rawBody.length > MAX_BODY_BYTES) {
      return apiPayloadTooLarge("Relationship synthesis payload too large");
    }
    const body = JSON.parse(rawBody) as RelationshipSynthesisRequest;
    body.activeHypotheses = parseActiveHypotheses(body.activeHypotheses);
    if (
      !body.userId ||
      !body.personNodeId ||
      !body.personLabel ||
      !Array.isArray(body.interactions) ||
      body.interactions.length < 2
    ) {
      return ephemeralAiJson(
        { error: "At least two cited interactions are required", code: "INVALID_REQUEST" },
        { status: 400 },
      );
    }
    const ordered = [...body.interactions].sort((a, b) =>
      a.occurredAt.localeCompare(b.occurredAt),
    );
    const sources = new Map(
      ordered.map((item) => [item.sourceEntryId, item.canonicalTranscript]),
    );
    if (
      sources.size !== ordered.length ||
      ordered.some(
        (item) =>
          !item.sourceEntryId ||
          !item.canonicalTranscript ||
          !Number.isFinite(item.emotionalValenceScore) ||
          (item.audioTimestampMs != null &&
            (!Number.isInteger(item.audioTimestampMs) ||
              item.audioTimestampMs < 0)),
      )
    ) {
      return ephemeralAiJson(
        { error: "Invalid or duplicate interaction evidence", code: "INVALID_REQUEST" },
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
    } = await buildHybridAiPromptContext(
      authenticatedUserId,
      body.activeHypotheses,
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
          content: `${SYSTEM_PROMPT}${correctionBlock ? `\n\n${correctionBlock}` : ""}${activeHypothesisContext ? `\n\n${activeHypothesisContext}` : ""}`,
        },
        {
          role: "user",
          content: JSON.stringify({
            personNodeId: body.personNodeId,
            personLabel: body.personLabel,
            interactions: ordered,
          }),
        },
      ],
    });
    await meterConfiguredOpenAiChatUsage({
      operation: "relationship-synthesis.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(completion),
      model,
      usage: completion.usage,
    });
    const content = completion.choices[0]?.message?.content;
    if (!content) throw new Error("RELATIONSHIP_SYNTHESIS_EMPTY");
    const result = JSON.parse(content) as RelationshipSynthesisResult;
    if (result.personNodeId !== body.personNodeId) {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return invalidModelResponse(["personNodeId mismatch"]);
    }
    const validation = validateExplainableConclusion(
      result.changeOverTime,
      sources,
      "changeOverTime",
      { crossRecordingClaim: true },
    );
    if (!validation.ok) {
      if (usageReservationId) await releaseUsageReservation(usageReservationId);
      return invalidModelResponse(validation.errors);
    }
    return ephemeralAiJson(result);
  } catch (error) {
    if (usageReservationId) await releaseUsageReservation(usageReservationId);
    logEphemeralAiFailure("relationship-synthesis", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return ephemeralAiJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}

function invalidModelResponse(errors: string[]) {
  return ephemeralAiJson(
    { error: "Relationship synthesis failed validation", code: "INVALID_MODEL_OUTPUT", errors },
    { status: 422 },
  );
}
