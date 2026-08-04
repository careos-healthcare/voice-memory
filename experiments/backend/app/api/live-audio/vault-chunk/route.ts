import { NextResponse } from "next/server";

import { logLiveAudio } from "@/lib/live-audio/live-audio-log";
import { recordVaultChunkUpload } from "@/lib/live-audio/vault-chunk-store";
import {
  apiUnauthorized,
  MAX_AUDIO_BYTES,
  resolveApiGuardContext,
  resolveCaptureAuthFailureCode,
} from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { meterBestEffort } from "@/lib/server/unit-economics-meter";

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
  return NextResponse.json(
    {
      route: "/api/live-audio/vault-chunk",
      methods: ["POST"],
      auth: "Authorization: Bearer <capture-token>",
      multipartFields: ["session_id", "chunk_id", "payload_envelope"],
      multipartFile: "audio",
      optionalHeaders: ["x-vm-idempotency-key", "x-vm-capture-token"],
      code: "METHOD_NOT_ALLOWED",
      error:
        "Use POST multipart/form-data with session_id, chunk_id, and audio binary.",
    },
    { status: 405 },
  );
}

/** Accepts one incremental emergency vault chunk with idempotent ACK semantics. */
export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const audio = formData.get("audio");
    const sessionId = readFormField(formData, "session_id", "sessionId");
    const chunkId = readFormField(formData, "chunk_id", "chunkId");
    const payloadEnvelopeRaw = readFormField(formData, "payload_envelope");

    if (!(audio instanceof File) || audio.size === 0) {
      return NextResponse.json(
        { error: "Encrypted chunk audio is required.", code: "CHUNK_REQUIRED" },
        { status: 400 },
      );
    }

    if (audio.size > MAX_AUDIO_BYTES) {
      return NextResponse.json(
        { error: "Chunk upload exceeds the allowed size.", code: "PAYLOAD_TOO_LARGE" },
        { status: 413 },
      );
    }

    if (!sessionId) {
      return NextResponse.json(
        { error: "session_id is required.", code: "SESSION_ID_REQUIRED" },
        { status: 400 },
      );
    }

    if (!chunkId) {
      return NextResponse.json(
        { error: "chunk_id is required.", code: "CHUNK_ID_REQUIRED" },
        { status: 400 },
      );
    }

    const idempotencyKey =
      request.headers.get("x-vm-idempotency-key")?.trim() ??
      `vault-chunk:${sessionId}:${chunkId}`;

    if (payloadEnvelopeRaw) {
      try {
        const envelope = JSON.parse(payloadEnvelopeRaw) as Record<string, unknown>;
        const envelopeSessionId =
          typeof envelope.session_id === "string" ? envelope.session_id : "";
        const envelopeChunkId = typeof envelope.id === "string" ? envelope.id : "";
        const envelopeIdempotencyKey =
          typeof envelope.idempotency_key === "string"
            ? envelope.idempotency_key
            : "";
        if (envelopeSessionId && envelopeSessionId !== sessionId) {
          return NextResponse.json(
            {
              error: "payload_envelope session_id mismatch.",
              code: "ENVELOPE_SESSION_MISMATCH",
            },
            { status: 400 },
          );
        }
        if (envelopeChunkId && envelopeChunkId !== chunkId) {
          return NextResponse.json(
            {
              error: "payload_envelope id mismatch.",
              code: "ENVELOPE_CHUNK_MISMATCH",
            },
            { status: 400 },
          );
        }
        if (
          envelopeIdempotencyKey &&
          envelopeIdempotencyKey !== idempotencyKey
        ) {
          return NextResponse.json(
            {
              error: "payload_envelope idempotency_key mismatch.",
              code: "ENVELOPE_IDEMPOTENCY_MISMATCH",
            },
            { status: 400 },
          );
        }
      } catch {
        return NextResponse.json(
          { error: "payload_envelope must be valid JSON.", code: "ENVELOPE_INVALID" },
          { status: 400 },
        );
      }
    }

    const auth = await resolveApiGuardContext(request);
    if (!auth) {
      const code = await resolveCaptureAuthFailureCode(request);
      return apiUnauthorized(code, "Sign in or attest this device before uploading.");
    }

    const audioBytes = Buffer.from(await audio.arrayBuffer());
    const result = recordVaultChunkUpload({
      sessionId,
      chunkId,
      idempotencyKey,
      audioBytes,
    });
    await meterBestEffort({
      operation: "vault-chunk.ingress",
      subject: auth,
      idempotencyKey,
      metric: "ingress_bytes",
      resource: "network.ingress",
      quantity: audioBytes.length,
      measurementBasis: "exact",
    });

    logLiveAudio(
      `vault chunk ingest bytes=${audioBytes.length} duplicate=${result.duplicate}`,
    );

    return NextResponse.json(
      {
        ok: true,
        chunkAckId: result.chunkAckId,
        duplicate: result.duplicate,
      },
      { status: result.duplicate ? 200 : 201 },
    );
  } catch (error) {
    console.error("Vault chunk ingest failed:", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return NextResponse.json(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
