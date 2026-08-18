import { NextResponse } from "next/server";

import {
  apiPayloadTooLarge,
  guardOpenAiRoute,
  MAX_AUDIO_BYTES,
} from "@/lib/server/api-guard";
import {
  apiErrorResponse,
  apiMethodNotAllowed,
} from "@/lib/server/api-error-response";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { getOpenAIClient } from "@/lib/openai";

export const runtime = "nodejs";

const MAX_DURATION_SECONDS = Number(
  process.env.VOICEMEMORY_MAX_RECORDING_SECONDS ?? "120",
);

export async function GET() {
  return apiMethodNotAllowed({
    route: "/api/transcribe",
    methods: ["POST"],
    message: "Use POST with multipart audio and x-vm-capture-token.",
    extra: {
      multipartField: "audio",
      captureTokenHeader: "x-vm-capture-token",
    },
  });
}

export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const audio = formData.get("audio");
    const durationRaw = formData.get("durationSeconds");
    const durationSeconds =
      typeof durationRaw === "string" ? Number(durationRaw) : Number(durationRaw ?? 0);

    if (!(audio instanceof File) || audio.size === 0) {
      return apiErrorResponse({ code: "AUDIO_REQUIRED", route: "transcribe" });
    }

    if (audio.size > MAX_AUDIO_BYTES) {
      return apiPayloadTooLarge(
        `Audio must be under ${Math.round(MAX_AUDIO_BYTES / (1024 * 1024))}MB.`,
      );
    }

    if (
      Number.isFinite(durationSeconds) &&
      durationSeconds > MAX_DURATION_SECONDS
    ) {
      return apiErrorResponse({ code: "DURATION_LIMIT", route: "transcribe" });
    }

    const guard = await guardOpenAiRoute(request, "transcribe", {
      durationSeconds: Number.isFinite(durationSeconds) ? durationSeconds : undefined,
      audioBytes: audio.size,
    });
    if (!guard.ok) return guard.response;

    const openai = getOpenAIClient();
    const transcription = await openai.audio.transcriptions.create({
      file: audio,
      model: "whisper-1",
      language: "en",
    });

    const transcript = transcription.text?.trim();

    if (!transcript) {
      return apiErrorResponse({ code: "NO_SPEECH", route: "transcribe" });
    }

    return NextResponse.json({ transcript });
  } catch (error) {
    console.error("Speech-to-text failed:", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return apiErrorResponse({
      code: safe.code,
      message: safe.message,
      status: 500,
      logEvent: "api_error",
      internalCategory: "internal_error",
      route: "transcribe",
    });
  }
}
