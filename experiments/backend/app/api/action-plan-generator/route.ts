import { Buffer } from "node:buffer";

import {
  ActionPlanGeneratorResultSchema,
  parseActionPlanGeneratorRequest,
  parseActionPlanGeneratorResult,
} from "@/lib/action-plan-generator/action-plan-generator-contract";
import { getOpenAIClient } from "@/lib/openai";
import {
  ephemeralAiJson,
  logEphemeralAiFailure,
} from "@/lib/privacy/ephemeral-ai-response";
import { isAllowedVoiceSessionOrigin } from "@/lib/server/allowed-api-origin";
import { guardOpenAiRoute } from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import {
  meterConfiguredOpenAiChatUsage,
  vendorRequestId,
} from "@/lib/server/unit-economics-meter";
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const MAX_ACTION_PLAN_GENERATOR_BODY_BYTES = 32 * 1024;

const SYSTEM_PROMPT = [
  "Create exactly three small, optional behavioral experiments using only the supplied anonymized structural tokens, request-scoped opaque node and edge IDs, aggregate metrics, and source-specific scalar data.",
  "Apply the two-minute rule: every micro-habit should be easy to begin in about two minutes.",
  "Use habit stacking when a safe structural cue is available, but stackingCue may be null.",
  "Call the outputs optional behavioral experiments, not directives, treatment, or guaranteed solutions.",
  "Do not diagnose, provide therapy, prescribe treatment, or make medical or mental-health claims.",
  "Use cautious, observational language for planTitle and targetOutcome; do not claim certainty, causation, identity, intent, or hidden motives.",
  "Never request, infer, invent, or reproduce original IDs, labels, titles, user or entry IDs, quotes, transcripts, evidence, content, audio, media, or paths.",
  "Each targetNodeId must exactly match a node ID supplied in the request.",
  "Return exactly three microHabits. For daily frequency customWeekdays must be empty; for custom_days it must contain one or more weekdays.",
].join(" ");

export async function GET() {
  return ephemeralAiJson(
    {
      route: "/api/action-plan-generator",
      methods: ["POST"],
      maxBodyBytes: MAX_ACTION_PLAN_GENERATOR_BODY_BYTES,
      captureTokenHeader: "x-vm-capture-token",
      nativeClientHeader: { name: "x-vm-client", value: "voicememory-mobile" },
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with strict anonymized structural data.",
    },
    { status: 405, headers: { Allow: "POST" } },
  );
}

export async function POST(request: Request) {
  if (!isAllowedVoiceSessionOrigin(request)) {
    return ephemeralAiJson(
      { error: "Request origin is not permitted.", code: "ORIGIN_NOT_ALLOWED" },
      { status: 403 },
    );
  }

  const declaredLength = Number(request.headers.get("content-length"));
  if (
    Number.isFinite(declaredLength) &&
    declaredLength > MAX_ACTION_PLAN_GENERATOR_BODY_BYTES
  ) {
    return payloadTooLarge();
  }

  let rawBody: string;
  try {
    rawBody = await readBoundedBody(
      request,
      MAX_ACTION_PLAN_GENERATOR_BODY_BYTES,
    );
  } catch (error) {
    if (error instanceof BodyTooLargeError) return payloadTooLarge();
    return ephemeralAiJson(
      { error: "Request body could not be read.", code: "INVALID_REQUEST" },
      { status: 400 },
    );
  }

  let body;
  try {
    body = parseActionPlanGeneratorRequest(JSON.parse(rawBody));
  } catch (error) {
    return ephemeralAiJson(
      {
        error: error instanceof Error ? error.message : "Invalid request.",
        code: "INVALID_REQUEST",
      },
      { status: 400 },
    );
  }

  const guard = await guardOpenAiRoute(request, "analyze", {
    transcriptChars: rawBody.length,
  });
  if (!guard.ok) return ephemeralGuardResponse(guard.response);

  try {
    const model =
      process.env.VOICEMEMORY_ACTION_PLAN_GENERATOR_MODEL?.trim() ||
      "gpt-4o-mini";
    const completion = await getOpenAIClient().chat.completions.create({
      model,
      store: false,
      temperature: 0.2,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: JSON.stringify(body) },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "action_plan_generator",
          strict: true,
          schema: ActionPlanGeneratorResultSchema,
        },
      },
    });

    await meterConfiguredOpenAiChatUsage({
      operation: "action-plan-generator.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(completion),
      model,
      usage: completion.usage,
    });

    const content = completion.choices[0]?.message.content;
    if (!content) throw new Error("ACTION_PLAN_GENERATOR_EMPTY");
    return ephemeralAiJson(
      parseActionPlanGeneratorResult(JSON.parse(content), body),
    );
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/action-plan-generator", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return ephemeralAiJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}

class BodyTooLargeError extends Error {}

async function readBoundedBody(
  request: Request,
  maxBytes: number,
): Promise<string> {
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel();
        throw new BodyTooLargeError();
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  return Buffer.concat(chunks).toString("utf8");
}

function payloadTooLarge() {
  return ephemeralAiJson(
    {
      error: "Action plan generator payload is too large.",
      code: "PAYLOAD_TOO_LARGE",
    },
    { status: 413 },
  );
}

async function ephemeralGuardResponse(response: Response) {
  const retryAfter = response.headers.get("retry-after");
  const responseBody = await response.json().catch(() => ({
    error: "Action plan generator is temporarily unavailable.",
    code: "ANALYZE_UNAVAILABLE",
  }));
  return ephemeralAiJson(responseBody, {
    status: response.status,
    headers: retryAfter ? { "Retry-After": retryAfter } : undefined,
  });
}
