import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { hashEmailForLog } from "@/lib/server/auth-route-log";
import {
  createSyncRouteLog,
  parseRequestJson,
  readContentLength,
  readRequestBodyText,
  summarizeBlobs,
} from "@/lib/server/sync-route-log";
import { upsertEncryptedBlobs } from "@/lib/server/sync-store";
import type { EncryptedPayload, SyncBlobType } from "@/types/sync";

export const runtime = "nodejs";

interface PushBody {
  blobs?: Array<{
    id: string;
    type: SyncBlobType;
    encrypted: EncryptedPayload;
    updatedAt: string;
    byteLength: number;
  }>;
}

/** Accept encrypted blobs only — reject plaintext archive fields. */
export async function POST(request: Request) {
  const { log } = createSyncRouteLog("push", "POST");

  const session = await getServerSession();
  if (!session) {
    log({ ok: false, errorCode: "SYNC_AUTH_REQUIRED", responseShape: "auth_required" });
    return syncApiUnauthorized();
  }

  log({ emailHash: hashEmailForLog(session.email) });

  const rawBody = await readRequestBodyText(request);
  const contentLength = readContentLength(request);
  log({
    contentLength,
    bodyPresent: rawBody.trim().length > 0,
  });

  const { data: body, success } = parseRequestJson<PushBody>(rawBody);
  log({ parseSuccess: success });

  if (!success || !body) {
    log({
      ok: false,
      errorCode: "INVALID_REMOTE_JSON",
      responseShape: "invalid_body",
    });
    return syncApiFailure("Request body must be valid JSON.", "INVALID_REMOTE_JSON", 400);
  }

  const blobs = body.blobs ?? [];
  if (blobs.length === 0) {
    log({
      ok: false,
      errorCode: "EMPTY_REMOTE_PAYLOAD",
      responseShape: "no_blobs",
      blobCount: 0,
    });
    return syncApiFailure("No encrypted blobs provided.", "EMPTY_REMOTE_PAYLOAD", 400);
  }

  const summary = summarizeBlobs(blobs);
  log(summary);

  for (const blob of blobs) {
    if (!blob.id || !blob.type || !blob.encrypted?.ciphertext || !blob.encrypted?.iv) {
      log({
        ok: false,
        errorCode: "INVALID_ENCRYPTED_ENVELOPE",
        responseShape: "invalid_blob",
      });
      return syncApiFailure("Invalid encrypted blob envelope.", "INVALID_ENCRYPTED_ENVELOPE", 400);
    }
    if (blob.encrypted.version !== 1) {
      log({
        ok: false,
        errorCode: "UNSUPPORTED_ENCRYPTION_VERSION",
        responseShape: "unsupported_version",
      });
      return syncApiFailure(
        "Unsupported encryption version.",
        "UNSUPPORTED_ENCRYPTION_VERSION",
        400,
      );
    }
  }

  try {
    const manifest = await upsertEncryptedBlobs(
      session.userId,
      blobs.map((blob) => ({
        id: blob.id,
        type: blob.type,
        encrypted: blob.encrypted,
        updatedAt: blob.updatedAt,
        byteLength: blob.byteLength,
      })),
    );

    log({
      ok: true,
      responseShape: "manifest",
      blobCount: manifest.blobs.length,
    });

    return syncApiSuccess({ manifest });
  } catch (error) {
    log({
      ok: false,
      errorCode: "SYNC_PUSH_FAILED",
      responseShape: "error",
    });
    return syncApiFailure(
      error instanceof Error ? error.message : "Encrypted backup could not be saved.",
      "SYNC_PUSH_FAILED",
      500,
    );
  }
}
