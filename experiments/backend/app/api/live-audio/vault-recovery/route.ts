import { NextResponse } from "next/server";

import { logLiveAudio } from "@/lib/live-audio/live-audio-log";
import {
  processVaultRecoveryUpload,
  VaultRecoveryProcessError,
} from "@/lib/live-audio/vault-recovery-process";
import {
  apiPayloadTooLarge,
  guardOpenAiRoute,
  MAX_AUDIO_BYTES,
} from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { requireRemoteTranscriptionDisclosure } from "@/lib/server/remote-transcription-disclosure";
import { meterBestEffort } from "@/lib/server/unit-economics-meter";
import {
  commitUsageReservation,
  releaseUsageReservation,
} from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";

const MAX_DURATION_SECONDS = Number(
  process.env.VOICEMEMORY_MAX_RECORDING_SECONDS ?? "120",
);

export async function GET() {
  return NextResponse.json(
    {
      route: "/api/live-audio/vault-recovery",
      methods: ["POST"],
      multipartField: "vault",
      captureTokenHeader: "x-vm-capture-token",
      idempotencyHeader: "x-vm-idempotency-key",
      code: "METHOD_NOT_ALLOWED",
      error:
        "Use POST with encrypted vault file, sessionId, durationSeconds, and capture auth headers.",
    },
    { status: 405 },
  );
}

/** Accepts an encrypted offline live-audio vault, decrypts server-side, transcribes, and analyzes. */
export async function POST(request: Request) {
  let usageReservationId: string | undefined;
  try {
    const disclosureError = requireRemoteTranscriptionDisclosure(request);
    if (disclosureError) return disclosureError;

    const idempotencyKey = request.headers.get("x-vm-idempotency-key")?.trim();
    if (!idempotencyKey) {
      return NextResponse.json(
        {
          error: "Idempotency key is required for vault recovery uploads.",
          code: "IDEMPOTENCY_REQUIRED",
        },
        { status: 400 },
      );
    }

    const formData = await request.formData();
    const vault = formData.get("vault");
    const sessionIdRaw = formData.get("sessionId");
    const durationRaw = formData.get("durationSeconds");

    if (!(vault instanceof File) || vault.size === 0) {
      return NextResponse.json(
        { error: "Encrypted vault file is required.", code: "VAULT_REQUIRED" },
        { status: 400 },
      );
    }

    if (vault.size > MAX_AUDIO_BYTES * 4) {
      return apiPayloadTooLarge("Vault upload exceeds the allowed size.");
    }

    const sessionId =
      typeof sessionIdRaw === "string" ? sessionIdRaw.trim() : "";
    if (!sessionId) {
      return NextResponse.json(
        { error: "sessionId is required.", code: "SESSION_ID_REQUIRED" },
        { status: 400 },
      );
    }

    const durationSeconds =
      typeof durationRaw === "string"
        ? Number(durationRaw)
        : Number(durationRaw ?? 0);
    if (
      !Number.isFinite(durationSeconds) ||
      durationSeconds <= 0 ||
      durationSeconds > MAX_DURATION_SECONDS
    ) {
      return NextResponse.json(
        {
          error: `durationSeconds must be between 1 and ${MAX_DURATION_SECONDS}.`,
          code: "DURATION_LIMIT",
        },
        { status: 400 },
      );
    }

    const guard = await guardOpenAiRoute(request, "transcribe", {
      durationSeconds,
      audioBytes: vault.size,
    });
    if (!guard.ok) return guard.response;
    usageReservationId = guard.ctx.monetization?.reservation?.reservationId;

    const vaultBytes = Buffer.from(await vault.arrayBuffer());
    const result = await processVaultRecoveryUpload({
      subject: guard.ctx.subject,
      sessionId,
      idempotencyKey,
      vaultBytes,
      durationSeconds,
    });
    if (usageReservationId) {
      await commitUsageReservation(
        usageReservationId,
        Math.max(1, Math.ceil(result.durationSeconds)),
      );
    }
    await meterBestEffort({
      operation: "vault-recovery.ingress",
      subject: guard.ctx,
      idempotencyKey,
      metric: "ingress_bytes",
      resource: "network.ingress",
      quantity: vaultBytes.length,
      measurementBasis: "exact",
    });

    logLiveAudio(
      `vault recovery complete duplicate=${result.duplicate} frameCount=${result.frameCount}`,
    );

    return NextResponse.json({
      ok: true,
      recoveryAckId: result.recoveryAckId,
      duplicate: result.duplicate,
      transcript: result.transcript,
      reflection: result.reflection,
      durationSeconds: result.durationSeconds,
      frameCount: result.frameCount,
    });
  } catch (error) {
    if (usageReservationId) await releaseUsageReservation(usageReservationId);
    if (error instanceof VaultRecoveryProcessError) {
      return NextResponse.json(
        { error: error.message, code: error.code },
        { status: error.status },
      );
    }
    console.error("Vault recovery failed:", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return NextResponse.json(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
