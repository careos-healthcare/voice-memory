import { NextResponse } from "next/server";

import { logLiveAudio } from "@/lib/live-audio/live-audio-log";
import {
  processVaultRecoveryUpload,
  VaultRecoveryProcessError,
} from "@/lib/live-audio/vault-recovery-process";
import { decodeVaultRecoverySecretField } from "@/lib/live-audio/vault-recovery-secret";
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
  return apiMethodNotAllowed({
    route: "/api/live-audio/recover",
    methods: ["POST"],
    message:
      "Use POST multipart/form-data with session_id, recovery_secret, and vault binary.",
    extra: {
      auth: "Authorization: Bearer <capture-token>",
      multipartFields: ["session_id", "recovery_secret"],
      multipartFile: "vault",
      optionalHeaders: ["x-vm-idempotency-key", "x-vm-capture-token"],
    },
  });
}

/** Dedicated vault ingestion target: decrypt AVME payload, transcribe, and analyze. */
export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const vault = formData.get("vault");
    const sessionId = readFormField(formData, "session_id", "sessionId");
    const recoverySecretRaw = readFormField(
      formData,
      "recovery_secret",
      "recoverySecret",
    );

    if (!(vault instanceof File) || vault.size === 0) {
      return apiErrorResponse({ code: "VAULT_REQUIRED", route: "live-audio/recover" });
    }

    if (vault.size > MAX_AUDIO_BYTES * 4) {
      return apiPayloadTooLarge("Vault upload exceeds the allowed size.");
    }

    if (!sessionId) {
      return apiErrorResponse({ code: "SESSION_ID_REQUIRED", route: "live-audio/recover" });
    }

    const inlineRecoverySecret = recoverySecretRaw
      ? decodeVaultRecoverySecretField(recoverySecretRaw)
      : null;
    if (recoverySecretRaw && !inlineRecoverySecret) {
      return apiErrorResponse({ code: "RECOVERY_SECRET_INVALID", route: "live-audio/recover" });
    }

    const idempotencyKey =
      request.headers.get("x-vm-idempotency-key")?.trim() ??
      `recover:${sessionId}`;

    const guard = await guardOpenAiRoute(request, "transcribe", {
      audioBytes: vault.size,
    });
    if (!guard.ok) return guard.response;

    const vaultBytes = Buffer.from(await vault.arrayBuffer());
    logLiveAudio(
      `vault recover ingest sessionId=${sessionId} bytes=${vaultBytes.length} hash=${hashVaultBytes(vaultBytes).slice(0, 12)}`,
    );

    const result = await processVaultRecoveryUpload({
      subject: guard.ctx.subject,
      sessionId,
      idempotencyKey,
      vaultBytes,
      inlineRecoverySecret,
    });

    logLiveAudio(
      `vault recover complete sessionId=${sessionId} ack=${result.recoveryAckId} duplicate=${result.duplicate}`,
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
    if (error instanceof VaultRecoveryProcessError) {
      return apiErrorResponse({
        code: error.code,
        status: error.status,
        route: "live-audio/recover",
      });
    }
    console.error("Vault recover ingest failed:", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return apiErrorResponse({
      code: safe.code,
      message: safe.message,
      status: 500,
      logEvent: "api_error",
      internalCategory: "internal_error",
      route: "live-audio/recover",
    });
  }
}
