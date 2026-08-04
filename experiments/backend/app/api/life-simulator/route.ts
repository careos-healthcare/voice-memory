import { Buffer } from "node:buffer";

import {
  LifeSimulatorResultSchema,
  parseLifeSimulatorRequest,
  parseLifeSimulatorResult,
} from "@/lib/life-simulator/life-simulator-contract";
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

export const MAX_LIFE_SIMULATOR_BODY_BYTES = 32 * 1024;

const SYSTEM_PROMPT = [
  "Generate two paired observational counterfactual trajectories using only the supplied anonymized structure: one if the target pattern continues, and one if it stops or pivots.",
  "This is a bounded simulation, not a prediction, diagnosis, medical assessment, causal claim, or instruction.",
  "Use cautious language such as may, could, or appears consistent with, and explicitly preserve uncertainty.",
  "Do not infer identity, protected traits, hidden motives, mental or physical conditions, or facts absent from the supplied aggregate signals.",
  "Treat healthCorrelation only as a non-medical correlation signal; never describe it as a diagnosis or certain personal health outcome.",
  "For each trajectory return milestones in exactly this order: 30, 90, and 365 days.",
  "projectedConfidence must be between 0 and 1; stressImpactScore and non-null healthCorrelation must be between -1 and 1.",
  "Use affectedIds only from supplied anonymous node or edge IDs.",
  "Use citationHandles only from the supplied opaque citation handles; never invent or transform a handle.",
  "Do not request or reproduce user IDs, entry IDs, quotes, transcripts, labels, evidence text, or audio/media paths.",
].join(" ");

export async function GET() {
  return ephemeralAiJson(
    {
      route: "/api/life-simulator",
      methods: ["POST"],
      maxBodyBytes: MAX_LIFE_SIMULATOR_BODY_BYTES,
      captureTokenHeader: "x-vm-capture-token",
      nativeClientHeader: { name: "x-vm-client", value: "voicememory-mobile" },
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with strict anonymized aggregate structure.",
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
    declaredLength > MAX_LIFE_SIMULATOR_BODY_BYTES
  ) {
    return payloadTooLarge();
  }

  let rawBody: string;
  try {
    rawBody = await readBoundedBody(request, MAX_LIFE_SIMULATOR_BODY_BYTES);
  } catch (error) {
    if (error instanceof BodyTooLargeError) return payloadTooLarge();
    return ephemeralAiJson(
      { error: "Request body could not be read.", code: "INVALID_REQUEST" },
      { status: 400 },
    );
  }

  let body;
  try {
    body = parseLifeSimulatorRequest(JSON.parse(rawBody));
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
      process.env.VOICEMEMORY_LIFE_SIMULATOR_MODEL?.trim() || "gpt-4o-mini";
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
          name: "life_simulator",
          strict: true,
          schema: LifeSimulatorResultSchema,
        },
      },
    });

    await meterConfiguredOpenAiChatUsage({
      operation: "life-simulator.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(completion),
      model,
      usage: completion.usage,
    });

    const content = completion.choices[0]?.message.content;
    if (!content) throw new Error("LIFE_SIMULATOR_EMPTY");
    return ephemeralAiJson(
      parseLifeSimulatorResult(JSON.parse(content), body),
    );
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/life-simulator", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return ephemeralAiJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}

class BodyTooLargeError extends Error {}

async function readBoundedBody(request: Request, maxBytes: number): Promise<string> {
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
      error: "Life simulator payload is too large.",
      code: "PAYLOAD_TOO_LARGE",
    },
    { status: 413 },
  );
}

async function ephemeralGuardResponse(response: Response) {
  const retryAfter = response.headers.get("retry-after");
  const responseBody = await response.json().catch(() => ({
    error: "Life simulator is temporarily unavailable.",
    code: "ANALYZE_UNAVAILABLE",
  }));
  return ephemeralAiJson(responseBody, {
    status: response.status,
    headers: retryAfter ? { "Retry-After": retryAfter } : undefined,
  });
}
