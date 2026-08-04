import { Buffer } from "node:buffer";

import { generateDocumentIngestion } from "@/backend/src/ai/document-ingestion/service";
import {
  DOCUMENT_INGESTION_PRIVACY_HEADERS,
  parseDocumentIngestionRequest,
} from "@/lib/document-ingestion/document-ingestion-contract";
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
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const MAX_DOCUMENT_INGESTION_BODY_BYTES = 32 * 1024;

export async function GET() {
  return ingestionJson(
    {
      route: "/api/document-ingestion",
      methods: ["POST"],
      maxBodyBytes: MAX_DOCUMENT_INGESTION_BODY_BYTES,
      captureTokenHeader: "x-vm-capture-token",
      nativeClientHeader: { name: "x-vm-client", value: "voicememory-mobile" },
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with explicitly selected bounded text chunks.",
    },
    { status: 405, headers: { Allow: "POST" } },
  );
}

export async function POST(request: Request) {
  if (!isAllowedVoiceSessionOrigin(request)) {
    return ingestionJson(
      { error: "Request origin is not permitted.", code: "ORIGIN_NOT_ALLOWED" },
      { status: 403 },
    );
  }

  if (!isJsonContentType(request.headers.get("content-type"))) {
    return ingestionJson(
      {
        error: "Content-Type must be application/json.",
        code: "INVALID_REQUEST",
      },
      { status: 415 },
    );
  }

  const declaredLength = Number(request.headers.get("content-length"));
  if (
    Number.isFinite(declaredLength) &&
    declaredLength > MAX_DOCUMENT_INGESTION_BODY_BYTES
  ) {
    return payloadTooLarge();
  }

  let rawBody: string;
  try {
    rawBody = await readBoundedBody(
      request,
      MAX_DOCUMENT_INGESTION_BODY_BYTES,
    );
  } catch (error) {
    if (error instanceof BodyTooLargeError) return payloadTooLarge();
    return ingestionJson(
      { error: "Request body could not be read.", code: "INVALID_REQUEST" },
      { status: 400 },
    );
  }

  let body;
  try {
    body = parseDocumentIngestionRequest(JSON.parse(rawBody));
  } catch (error) {
    return ingestionJson(
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
    const generation = await generateDocumentIngestion(body);
    await meterConfiguredOpenAiChatUsage({
      operation: "document-ingestion.chat",
      subject: guard.ctx,
      idempotencyKey: vendorRequestId(generation.completion),
      model: generation.model,
      usage: generation.completion.usage,
    });
    return ingestionJson(generation.result);
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/document-ingestion", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return ingestionJson(
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

function isJsonContentType(value: string | null): boolean {
  return value?.split(";", 1)[0]?.trim().toLowerCase() === "application/json";
}

function payloadTooLarge() {
  return ingestionJson(
    {
      error: "Document ingestion payload is too large.",
      code: "PAYLOAD_TOO_LARGE",
    },
    { status: 413 },
  );
}

async function ephemeralGuardResponse(response: Response) {
  const retryAfter = response.headers.get("retry-after");
  const responseBody = await response.json().catch(() => ({
    error: "Document ingestion is temporarily unavailable.",
    code: "ANALYZE_UNAVAILABLE",
  }));
  return ingestionJson(responseBody, {
    status: response.status,
    headers: retryAfter ? { "Retry-After": retryAfter } : undefined,
  });
}

function ingestionJson(body: unknown, init?: ResponseInit) {
  return ephemeralAiJson(body, {
    ...init,
    headers: {
      ...DOCUMENT_INGESTION_PRIVACY_HEADERS,
      ...init?.headers,
    },
  });
}
