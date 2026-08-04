import { Buffer } from "node:buffer";

import {
  HORIZON_PRIVACY_HEADERS,
  parseHorizonSimulationRequest,
  parseHorizonSimulationResult,
} from "@/backend/src/api/horizon-simulation/contracts";
import { HorizonSimulationResultSchema } from "@/backend/src/api/horizon-simulation/schema";
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
export const MAX_HORIZON_SIMULATION_BODY_BYTES = 24 * 1024;

const SYSTEM_PROMPT = [
  "Act as a cautious strategic futures analyst using only the supplied anonymized topology and scalar parameters.",
  "Generate exactly three probabilistic downstream nodes for 1, 3, and 5 years.",
  "For each horizon score financial, emotional, career, cognitiveLoad, alignment, and reward from 0 to 1, plus concise ripple effects.",
  "This is a scenario exploration, not a prediction, diagnosis, financial advice, career advice, or statement of fact.",
  "Use conditional language and preserve uncertainty. Never infer identity, protected traits, hidden motives, health conditions, or facts absent from the aggregate input.",
  "Do not request or reproduce names, user IDs, node IDs, cluster IDs, journal text, quotes, transcripts, labels, evidence, media, or file paths.",
].join(" ");

export async function GET() {
  return horizonJson(
    {
      route: "/api/horizon-simulation",
      methods: ["POST"],
      maxBodyBytes: MAX_HORIZON_SIMULATION_BODY_BYTES,
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with anonymized aggregate scenario signals.",
    },
    { status: 405, headers: { Allow: "POST" } },
  );
}

export async function POST(request: Request) {
  if (!isAllowedVoiceSessionOrigin(request)) {
    return horizonJson(
      { error: "Request origin is not permitted.", code: "ORIGIN_NOT_ALLOWED" },
      { status: 403 },
    );
  }
  const declaredLength = Number(request.headers.get("content-length"));
  if (
    Number.isFinite(declaredLength) &&
    declaredLength > MAX_HORIZON_SIMULATION_BODY_BYTES
  ) {
    return tooLarge();
  }
  let rawBody: string;
  try {
    rawBody = await readBoundedBody(
      request,
      MAX_HORIZON_SIMULATION_BODY_BYTES,
    );
  } catch {
    return tooLarge();
  }
  let body;
  try {
    body = parseHorizonSimulationRequest(JSON.parse(rawBody));
  } catch (error) {
    return horizonJson(
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
      process.env.VOICEMEMORY_HORIZON_MODEL?.trim() || "gpt-4o-mini";
    const completion = await getOpenAIClient().chat.completions.create({
      model,
      store: false,
      temperature: 0.25,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: JSON.stringify(body) },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "horizon_simulation",
          strict: true,
          schema: HorizonSimulationResultSchema,
        },
      },
    });
    await meterConfiguredOpenAiChatUsage({
      operation: "horizon-simulation.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(completion),
      model,
      usage: completion.usage,
    });
    const content = completion.choices[0]?.message.content;
    if (!content) throw new Error("HORIZON_SIMULATION_EMPTY");
    return horizonJson(parseHorizonSimulationResult(JSON.parse(content)));
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/horizon-simulation", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return horizonJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}

class BodyTooLargeError extends Error {}

async function readBoundedBody(
  request: Request,
  maximum: number,
): Promise<string> {
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let bytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > maximum) {
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

function tooLarge() {
  return horizonJson(
    {
      error: "Horizon simulation payload is too large.",
      code: "PAYLOAD_TOO_LARGE",
    },
    { status: 413 },
  );
}

async function ephemeralGuardResponse(response: Response) {
  const retryAfter = response.headers.get("retry-after");
  const body = await response.json().catch(() => ({
    error: "Horizon simulation is temporarily unavailable.",
    code: "ANALYZE_UNAVAILABLE",
  }));
  return horizonJson(body, {
    status: response.status,
    headers: retryAfter ? { "Retry-After": retryAfter } : undefined,
  });
}

function horizonJson(body: unknown, init?: ResponseInit) {
  return ephemeralAiJson(body, {
    ...init,
    headers: {
      ...HORIZON_PRIVACY_HEADERS,
      ...init?.headers,
    },
  });
}
