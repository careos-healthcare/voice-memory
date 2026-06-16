import { NextResponse } from "next/server";

import {
  apiPayloadTooLarge,
  guardOpenAiRoute,
  MAX_AUDIO_BYTES,
} from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { getOpenAIClient } from "@/lib/openai";

export const runtime = "nodejs";

const MAX_DURATION_SECONDS = Number(
  process.env.VOICEMEMORY_MAX_RECORDING_SECONDS ?? "120",
);

export async function GET() {
  return NextResponse.json(
    {
      route: "/api/transcribe",
      methods: ["POST"],
      multipartField: "audio",
      captureTokenHeader: "x-vm-capture-token",
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with multipart audio and x-vm-capture-token.",
    },
    { status: 405 },
  );
}

export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const audio = formData.get("audio");
    const durationRaw = formData.get("durationSeconds");
    const durationSeconds =
      typeof durationRaw === "string" ? Number(durationRaw) : Number(durationRaw ?? 0);

    if (!(audio instanceof File) || audio.size === 0) {
      return NextResponse.json(
        { error: "Audio file is required", code: "AUDIO_REQUIRED" },
        { status: 400 },
      );
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
      return NextResponse.json(
        {
          error: `Recording must be under ${MAX_DURATION_SECONDS} seconds.`,
          code: "DURATION_LIMIT",
        },
        { status: 400 },
      );
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
      return NextResponse.json(
        { error: "Could not detect speech in the recording", code: "NO_SPEECH" },
        { status: 422 },
      );
    }

    return NextResponse.json({ transcript });
  } catch (error) {
    console.error("Speech-to-text failed:", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return NextResponse.json(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
