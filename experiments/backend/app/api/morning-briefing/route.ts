import { Buffer } from "node:buffer";

import {
  MORNING_BRIEFING_PRIVACY_HEADERS,
  parseMorningBriefingRequest,
} from "@/backend/src/ai/morning-briefing/contracts";
import {
  buildMorningBriefingApiResponse,
  generateMorningBriefing,
  synthesizeMorningBriefingAudio,
} from "@/backend/src/ai/morning-briefing/service";
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
import {
  commitUsageReservation,
  releaseUsageReservation,
} from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const MAX_MORNING_BRIEFING_BODY_BYTES = 32 * 1024;

export async function GET() {
  return briefingJson(
    {
      route: "/api/morning-briefing",
      methods: ["POST"],
      maxBodyBytes: MAX_MORNING_BRIEFING_BODY_BYTES,
      captureTokenHeader: "x-vm-capture-token",
      nativeClientHeader: { name: "x-vm-client", value: "voicememory-mobile" },
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with strict anonymized aggregate data.",
    },
    { status: 405, headers: { Allow: "POST" } },
  );
}

export async function POST(request: Request) {
  if (!isAllowedVoiceSessionOrigin(request)) {
    return briefingJson(
      { error: "Request origin is not permitted.", code: "ORIGIN_NOT_ALLOWED" },
      { status: 403 },
    );
  }

  const declaredLength = Number(request.headers.get("content-length"));
  if (
    Number.isFinite(declaredLength) &&
    declaredLength > MAX_MORNING_BRIEFING_BODY_BYTES
  ) {
    return payloadTooLarge();
  }

  let rawBody: string;
  try {
    rawBody = await readBoundedBody(
      request,
      MAX_MORNING_BRIEFING_BODY_BYTES,
    );
  } catch (error) {
    if (error instanceof BodyTooLargeError) return payloadTooLarge();
    return briefingJson(
      { error: "Request body could not be read.", code: "INVALID_REQUEST" },
      { status: 400 },
    );
  }

  let body;
  try {
    body = parseMorningBriefingRequest(JSON.parse(rawBody));
  } catch (error) {
    return briefingJson(
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
    const generation = await generateMorningBriefing(body);
    if (generation.completion) {
      await meterConfiguredOpenAiChatUsage({
        operation: "morning-briefing.chat",
        subject: guard.ctx,
        idempotencyKey: vendorRequestId(generation.completion),
        model: generation.model,
        usage: generation.completion.usage,
      });
    }
    const audioBase64 = await synthesizeMorningBriefingAudio(
      generation.briefing,
    );
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) {
      if (generation.completion || audioBase64) {
        await commitUsageReservation(reservationId, 1);
      } else {
        await releaseUsageReservation(reservationId);
      }
    }
    return briefingJson(
      buildMorningBriefingApiResponse(generation.briefing, audioBase64),
      {
        headers: {
          "X-Morning-Briefing-Fallback": generation.fallbackUsed
            ? "true"
            : "false",
          "X-Morning-Briefing-Audio": audioBase64 ? "included" : "omitted",
        },
      },
    );
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/morning-briefing", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return briefingJson(
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
  return briefingJson(
    {
      error: "Morning briefing payload is too large.",
      code: "PAYLOAD_TOO_LARGE",
    },
    { status: 413 },
  );
}

async function ephemeralGuardResponse(response: Response) {
  const retryAfter = response.headers.get("retry-after");
  const responseBody = await response.json().catch(() => ({
    error: "Morning briefing is temporarily unavailable.",
    code: "ANALYZE_UNAVAILABLE",
  }));
  return briefingJson(responseBody, {
    status: response.status,
    headers: retryAfter ? { "Retry-After": retryAfter } : undefined,
  });
}

function briefingJson(body: unknown, init?: ResponseInit) {
  return ephemeralAiJson(body, {
    ...init,
    headers: {
      ...MORNING_BRIEFING_PRIVACY_HEADERS,
      ...init?.headers,
    },
  });
}
