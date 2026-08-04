import { NextResponse } from "next/server";

import {
  apiPayloadTooLarge,
  guardOpenAiRoute,
  MAX_AUDIO_BYTES,
  type ApiGuardContext,
} from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { requireRemoteTranscriptionDisclosure } from "@/lib/server/remote-transcription-disclosure";
import { getOpenAIClient } from "@/lib/openai";
import {
  meterBestEffort,
  transcriptionDurationMilliseconds,
  vendorRequestId,
} from "@/lib/server/unit-economics-meter";
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

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
  let guardContext: ApiGuardContext | undefined;
  try {
    const disclosureError = requireRemoteTranscriptionDisclosure(request);
    if (disclosureError) return disclosureError;

    const requestIngressBytes = (await request.clone().arrayBuffer()).byteLength;
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
    if (
      process.env.NODE_ENV === "production" &&
      (!Number.isFinite(durationSeconds) || durationSeconds <= 0)
    ) {
      return NextResponse.json(
        {
          error: "durationSeconds is required for metered transcription.",
          code: "USAGE_UNITS_REQUIRED",
          preserveLocalContent: true,
        },
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
      durationSeconds:
        Number.isFinite(durationSeconds) && durationSeconds > 0
          ? durationSeconds
          : undefined,
      audioBytes: audio.size,
    });
    if (!guard.ok) return guard.response;
    guardContext = guard.ctx;

    const openai = getOpenAIClient();
    const transcription = await openai.audio.transcriptions.create({
      file: audio,
      model: "whisper-1",
      language: "en",
      response_format: "verbose_json",
    });

    const transcript = transcription.text?.trim();

    if (!transcript) {
      const reservationId = guard.ctx.monetization?.reservation?.reservationId;
      if (reservationId) await releaseUsageReservation(reservationId);
      return NextResponse.json(
        { error: "Could not detect speech in the recording", code: "NO_SPEECH" },
        { status: 422 },
      );
    }

    const vendorDuration =
      "duration" in transcription && typeof transcription.duration === "number"
        ? transcription.duration
        : null;
    const meteredDuration = transcriptionDurationMilliseconds(
      vendorDuration,
      undefined,
    );
    if (meteredDuration === null) {
      throw new Error("TRANSCRIPTION_DURATION_UNAVAILABLE");
    }
    const idempotencyKey = vendorRequestId(
      transcription,
      request.headers.get("x-vm-idempotency-key"),
    );
    await Promise.all([
      meterBestEffort({
        operation: "transcribe.ingress",
        subject: guard.ctx,
        idempotencyKey,
        metric: "ingress_bytes",
        resource: "network.ingress",
        quantity: requestIngressBytes,
        measurementBasis: "exact",
      }),
      meterBestEffort({
        operation: "transcribe.audio",
        subject: guard.ctx,
        idempotencyKey,
        metric: "transcription_audio_milliseconds",
        resource: "openai.whisper-1",
        quantity: meteredDuration.quantity,
        dimensions: { provider: "openai", model: "whisper-1" },
        measurementBasis: meteredDuration.basis,
      }),
    ]);

    return NextResponse.json({ transcript });
  } catch (error) {
    const reservationId = guardContext?.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    console.error("Speech-to-text failed:", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return NextResponse.json(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
