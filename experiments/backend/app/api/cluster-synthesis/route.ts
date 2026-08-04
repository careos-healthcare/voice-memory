import { Buffer } from "node:buffer";

import {
  ClusterSynthesisResultSchema,
  parseClusterSynthesisRequest,
  parseClusterSynthesisResult,
} from "@/lib/cluster-synthesis/cluster-synthesis-contract";
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

export const MAX_CLUSTER_SYNTHESIS_BODY_BYTES = 24 * 1024;

const SYSTEM_PROMPT = [
  "Name and briefly summarize one locally computed graph cluster using only the supplied anonymized structural labels and aggregate metrics.",
  "Treat the candidate title as a suggestion, not a fact.",
  "Use observational, tentative language grounded in visible graph structure.",
  "Do not infer identity, intent, personality, protected traits, mental or physical health conditions, diagnoses, causes, or hidden motives.",
  "Do not claim access to transcripts, evidence, audio, raw content, or user identity.",
  "Keep the title concise and the summary to one brief sentence.",
].join(" ");

export async function GET() {
  return ephemeralAiJson(
    {
      route: "/api/cluster-synthesis",
      methods: ["POST"],
      maxBodyBytes: MAX_CLUSTER_SYNTHESIS_BODY_BYTES,
      captureTokenHeader: "x-vm-capture-token",
      nativeClientHeader: { name: "x-vm-client", value: "voicememory-mobile" },
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with anonymized cluster structure and aggregate metrics.",
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
    declaredLength > MAX_CLUSTER_SYNTHESIS_BODY_BYTES
  ) {
    return payloadTooLarge();
  }

  const rawBody = await request.text();
  const bodyBytes = Buffer.byteLength(rawBody, "utf8");
  if (bodyBytes > MAX_CLUSTER_SYNTHESIS_BODY_BYTES) {
    return payloadTooLarge();
  }

  let body;
  try {
    body = parseClusterSynthesisRequest(JSON.parse(rawBody));
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
      process.env.VOICEMEMORY_CLUSTER_SYNTHESIS_MODEL?.trim() ||
      "gpt-4o-mini";
    const completion = await getOpenAIClient().chat.completions.create({
      model,
      store: false,
      temperature: 0.2,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: JSON.stringify(body),
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "cluster_synthesis",
          strict: true,
          schema: ClusterSynthesisResultSchema,
        },
      },
    });

    await meterConfiguredOpenAiChatUsage({
      operation: "cluster-synthesis.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(completion),
      model,
      usage: completion.usage,
    });

    const content = completion.choices[0]?.message.content;
    if (!content) throw new Error("CLUSTER_SYNTHESIS_EMPTY");
    return ephemeralAiJson(parseClusterSynthesisResult(JSON.parse(content)));
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/cluster-synthesis", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return ephemeralAiJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}

function payloadTooLarge() {
  return ephemeralAiJson(
    {
      error: "Cluster synthesis payload is too large.",
      code: "PAYLOAD_TOO_LARGE",
    },
    { status: 413 },
  );
}

async function ephemeralGuardResponse(response: Response) {
  const retryAfter = response.headers.get("retry-after");
  const body = await response.json().catch(() => ({
    error: "Cluster synthesis is temporarily unavailable.",
    code: "ANALYZE_UNAVAILABLE",
  }));
  return ephemeralAiJson(body, {
    status: response.status,
    headers: retryAfter ? { "Retry-After": retryAfter } : undefined,
  });
}
