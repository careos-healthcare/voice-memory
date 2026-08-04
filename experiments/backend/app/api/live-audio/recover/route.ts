import { NextResponse } from "next/server";

import { logLiveAudio } from "@/lib/live-audio/live-audio-log";
import {
  processVaultRecoveryUpload,
  VaultRecoveryProcessError,
} from "@/lib/live-audio/vault-recovery-process";
import { decodeVaultRecoverySecretField } from "@/lib/live-audio/vault-recovery-secret";
import {
  apiPayloadTooLarge,
  guardOpenAiRoute,
  MAX_AUDIO_BYTES,
} from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { requireRemoteTranscriptionDisclosure } from "@/lib/server/remote-transcription-disclosure";
import {
  commitUsageReservation,
  releaseUsageReservation,
} from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
const MAX_DURATION_SECONDS = Number(
  process.env.VOICEMEMORY_MAX_RECORDING_SECONDS ?? "120",
);

function readFormField(formData: FormData, ...keys: string[]): string {
  for (const key of keys) {
    const value = formData.get(key);
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }
  return "";
}

export async function GET() {
  return NextResponse.json(
    {
      route: "/api/live-audio/recover",
      methods: ["POST"],
      auth: "Authorization: Bearer <capture-token>",
      multipartFields: ["session_id", "recovery_secret"],
      multipartFile: "vault",
      optionalHeaders: ["x-vm-idempotency-key", "x-vm-capture-token"],
      code: "METHOD_NOT_ALLOWED",
      error:
        "Use POST multipart/form-data with session_id, recovery_secret, and vault binary.",
    },
    { status: 405 },
  );
}

/** Dedicated vault ingestion target: decrypt AVME payload, transcribe, and analyze. */
export async function POST(request: Request) {
  let usageReservationId: string | undefined;
  try {
    const disclosureError = requireRemoteTranscriptionDisclosure(request);
    if (disclosureError) return disclosureError;

    const formData = await request.formData();
    const vault = formData.get("vault");
    const sessionId = readFormField(formData, "session_id", "sessionId");
    const durationRaw = readFormField(
      formData,
      "duration_seconds",
      "durationSeconds",
    );
    const recoverySecretRaw = readFormField(
      formData,
      "recovery_secret",
      "recoverySecret",
    );

    if (!(vault instanceof File) || vault.size === 0) {
      return NextResponse.json(
        { error: "Encrypted vault file is required.", code: "VAULT_REQUIRED" },
        { status: 400 },
      );
    }

    if (vault.size > MAX_AUDIO_BYTES * 4) {
      return apiPayloadTooLarge("Vault upload exceeds the allowed size.");
    }

    if (!sessionId) {
      return NextResponse.json(
        { error: "session_id is required.", code: "SESSION_ID_REQUIRED" },
        { status: 400 },
      );
    }
    const durationSeconds = Number(durationRaw);
    if (
      !Number.isFinite(durationSeconds) ||
      durationSeconds <= 0 ||
      durationSeconds > MAX_DURATION_SECONDS
    ) {
      return NextResponse.json(
        {
          error: `duration_seconds must be between 1 and ${MAX_DURATION_SECONDS}.`,
          code: "USAGE_UNITS_REQUIRED",
          preserveLocalContent: true,
        },
        { status: 400 },
      );
    }

    const inlineRecoverySecret = recoverySecretRaw
      ? decodeVaultRecoverySecretField(recoverySecretRaw)
      : null;
    if (recoverySecretRaw && !inlineRecoverySecret) {
      return NextResponse.json(
        {
          error: "recovery_secret must be 32-byte base64url, base64, or hex.",
          code: "RECOVERY_SECRET_INVALID",
        },
        { status: 400 },
      );
    }

    const idempotencyKey =
      request.headers.get("x-vm-idempotency-key")?.trim() ??
      `recover:${sessionId}`;

    const guard = await guardOpenAiRoute(request, "transcribe", {
      audioBytes: vault.size,
      durationSeconds,
    });
    if (!guard.ok) return guard.response;
    usageReservationId = guard.ctx.monetization?.reservation?.reservationId;

    const vaultBytes = Buffer.from(await vault.arrayBuffer());
    const result = await processVaultRecoveryUpload({
      subject: guard.ctx.subject,
      sessionId,
      idempotencyKey,
      vaultBytes,
      inlineRecoverySecret,
      durationSeconds,
    });
    if (usageReservationId) {
      await commitUsageReservation(
        usageReservationId,
        Math.max(1, Math.ceil(result.durationSeconds)),
      );
    }

    logLiveAudio(
      `vault recover complete duplicate=${result.duplicate} frameCount=${result.frameCount}`,
    );

    return NextResponse.json(
      {
        ok: true,
        recoveryAckId: result.recoveryAckId,
        duplicate: result.duplicate,
        transcript: result.transcript,
        reflection: result.reflection,
        durationSeconds: result.durationSeconds,
        frameCount: result.frameCount,
      },
      { status: result.duplicate ? 200 : 201 },
    );
  } catch (error) {
    if (usageReservationId) await releaseUsageReservation(usageReservationId);
    if (error instanceof VaultRecoveryProcessError) {
      return NextResponse.json(
        { error: error.message, code: error.code },
        { status: error.status },
      );
    }
    console.error("Vault recover ingest failed:", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return NextResponse.json(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
