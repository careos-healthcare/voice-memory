import { Buffer } from "node:buffer";

import {
  LIFE_STORY_REPLAY_PRIVACY_HEADERS,
  parseLifeStoryReplayRequest,
} from "@/backend/src/ai/life-story-replay/contracts";
import {
  generateLifeStoryReplay,
  synthesizeLifeStoryAudio,
} from "@/backend/src/ai/life-story-replay/service";
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
export const MAX_LIFE_STORY_REPLAY_BODY_BYTES = 64 * 1024;

export async function GET() {
  return replayJson(
    {
      route: "/api/life-story-replay",
      methods: ["POST"],
      maxBodyBytes: MAX_LIFE_STORY_REPLAY_BODY_BYTES,
      code: "METHOD_NOT_ALLOWED",
    },
    { status: 405, headers: { Allow: "POST" } },
  );
}

export async function POST(request: Request) {
  if (!isAllowedVoiceSessionOrigin(request)) {
    return replayJson(
      { error: "Request origin is not permitted.", code: "ORIGIN_NOT_ALLOWED" },
      { status: 403 },
    );
  }
  let rawBody: string;
  try {
    rawBody = await readBoundedBody(
      request,
      MAX_LIFE_STORY_REPLAY_BODY_BYTES,
    );
  } catch {
    return replayJson(
      { error: "Replay payload is too large.", code: "PAYLOAD_TOO_LARGE" },
      { status: 413 },
    );
  }
  let body;
  try {
    body = parseLifeStoryReplayRequest(JSON.parse(rawBody));
  } catch (error) {
    return replayJson(
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
  if (!guard.ok) {
    const responseBody = await guard.response.json().catch(() => ({
      error: "Life story replay is temporarily unavailable.",
      code: "ANALYZE_UNAVAILABLE",
    }));
    return replayJson(responseBody, { status: guard.response.status });
  }
  try {
    const generation = await generateLifeStoryReplay(body);
    if (generation.completion) {
      await meterConfiguredOpenAiChatUsage({
        operation: "life-story-replay.chat",
        subject: guard.ctx,
        idempotencyKey: vendorRequestId(generation.completion),
        model: generation.model,
        usage: generation.completion.usage,
      });
    }
    const audioChunks = await synthesizeLifeStoryAudio(generation.replay);
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) {
      if (generation.completion || audioChunks.length > 0) {
        await commitUsageReservation(reservationId, 1);
      } else {
        await releaseUsageReservation(reservationId);
      }
    }
    return replayJson(
      { replay: generation.replay, audioChunks },
      {
        headers: {
          "X-Life-Story-Fallback": generation.fallbackUsed ? "true" : "false",
        },
      },
    );
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/life-story-replay", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return replayJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}

class BodyTooLargeError extends Error {}

async function readBoundedBody(request: Request, maximum: number) {
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maximum) {
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

function replayJson(body: unknown, init?: ResponseInit) {
  return ephemeralAiJson(body, {
    ...init,
    headers: {
      ...LIFE_STORY_REPLAY_PRIVACY_HEADERS,
      ...init?.headers,
    },
  });
}

