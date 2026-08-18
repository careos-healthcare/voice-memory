import { NextResponse } from "next/server";

import { logLiveAudio } from "@/lib/live-audio/live-audio-log";
import {
  processVaultRecoveryUpload,
  VaultRecoveryProcessError,
} from "@/lib/live-audio/vault-recovery-process";
import { hashVaultBytes } from "@/lib/live-audio/vault-recovery-store";
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

export const runtime = "nodejs";

const MAX_DURATION_SECONDS = Number(
  process.env.VOICEMEMORY_MAX_RECORDING_SECONDS ?? "120",
);

export async function GET() {
  return apiMethodNotAllowed({
    route: "/api/live-audio/vault-recovery",
    methods: ["POST"],
    message:
      "Use POST with encrypted vault file, sessionId, durationSeconds, and capture auth headers.",
    extra: {
      multipartField: "vault",
      captureTokenHeader: "x-vm-capture-token",
      idempotencyHeader: "x-vm-idempotency-key",
    },
  });
}

/** Accepts an encrypted offline live-audio vault, decrypts server-side, transcribes, and analyzes. */
export async function POST(request: Request) {
  try {
    const idempotencyKey = request.headers.get("x-vm-idempotency-key")?.trim();
    if (!idempotencyKey) {
      return apiErrorResponse({ code: "IDEMPOTENCY_REQUIRED", route: "live-audio/vault-recovery" });
    }

    const formData = await request.formData();
    const vault = formData.get("vault");
    const sessionIdRaw = formData.get("sessionId");
    const durationRaw = formData.get("durationSeconds");

    if (!(vault instanceof File) || vault.size === 0) {
      return apiErrorResponse({ code: "VAULT_REQUIRED", route: "live-audio/vault-recovery" });
    }

    if (vault.size > MAX_AUDIO_BYTES * 4) {
      return apiPayloadTooLarge("Vault upload exceeds the allowed size.");
    }

    const sessionId =
      typeof sessionIdRaw === "string" ? sessionIdRaw.trim() : "";
    if (!sessionId) {
      return apiErrorResponse({ code: "SESSION_ID_REQUIRED", route: "live-audio/vault-recovery" });
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
      return apiErrorResponse({ code: "DURATION_LIMIT", route: "live-audio/vault-recovery" });
    }

    const guard = await guardOpenAiRoute(request, "transcribe", {
      durationSeconds,
      audioBytes: vault.size,
    });
    if (!guard.ok) return guard.response;

    const vaultBytes = Buffer.from(await vault.arrayBuffer());
    logLiveAudio(
      `vault recovery upload sessionId=${sessionId} bytes=${vaultBytes.length} hash=${hashVaultBytes(vaultBytes).slice(0, 12)}`,
    );

    const result = await processVaultRecoveryUpload({
      subject: guard.ctx.subject,
      sessionId,
      idempotencyKey,
      vaultBytes,
      durationSeconds,
    });

    logLiveAudio(
      `vault recovery complete sessionId=${sessionId} ack=${result.recoveryAckId} duplicate=${result.duplicate}`,
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
    if (error instanceof VaultRecoveryProcessError) {
      return apiErrorResponse({
        code: error.code,
        status: error.status,
        route: "live-audio/vault-recovery",
      });
    }
    console.error("Vault recovery failed:", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return apiErrorResponse({
      code: safe.code,
      message: safe.message,
      status: 500,
      logEvent: "api_error",
      internalCategory: "internal_error",
      route: "live-audio/vault-recovery",
    });
  }
}
