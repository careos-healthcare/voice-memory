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
    binding?: string;
  }>;
}

const MAX_SYNC_PUSH_BLOBS = 32;
const MAX_SYNC_PUSH_BODY_BYTES = 8 * 1024 * 1024;
const MAX_SYNC_BLOB_BYTES = 2 * 1024 * 1024;

function isValidIsoTimestamp(value: string | undefined): boolean {
  if (!value?.trim()) return false;
  const time = new Date(value).getTime();
  return Number.isFinite(time);
}

/** Accept encrypted blobs only — reject plaintext archive fields. */
export async function POST(request: Request) {
  const { requestId, log } = createSyncRouteLog("push", "POST");

  const session = await getServerSession();
  if (!session) {
    log({ ok: false, errorCode: "SYNC_AUTH_REQUIRED", responseShape: "auth_required" });
    return syncApiUnauthorized(requestId);
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
    return syncApiFailure("INVALID_REMOTE_JSON", { status: 400, requestId });
  }

  if (contentLength != null && contentLength > MAX_SYNC_PUSH_BODY_BYTES) {
    log({
      ok: false,
      errorCode: "SYNC_PUSH_TOO_LARGE",
      responseShape: "body_too_large",
    });
    return syncApiFailure("SYNC_PUSH_TOO_LARGE", { status: 413, requestId });
  }

  const blobs = body.blobs ?? [];
  if (blobs.length > MAX_SYNC_PUSH_BLOBS) {
    log({
      ok: false,
      errorCode: "SYNC_PUSH_TOO_MANY_BLOBS",
      responseShape: "too_many_blobs",
      blobCount: blobs.length,
    });
    return syncApiFailure("SYNC_PUSH_TOO_MANY_BLOBS", { status: 400, requestId });
  }

  if (blobs.length === 0) {
    log({
      ok: false,
      errorCode: "EMPTY_REMOTE_PAYLOAD",
      responseShape: "no_blobs",
      blobCount: 0,
    });
    return syncApiFailure("EMPTY_REMOTE_PAYLOAD", { status: 400, requestId });
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
      return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", { status: 400, requestId });
    }
    if (blob.byteLength > MAX_SYNC_BLOB_BYTES) {
      log({
        ok: false,
        errorCode: "SYNC_BLOB_TOO_LARGE",
        responseShape: "blob_too_large",
      });
      return syncApiFailure("SYNC_BLOB_TOO_LARGE", { status: 413, requestId });
    }
    if (!isValidIsoTimestamp(blob.updatedAt)) {
      log({
        ok: false,
        errorCode: "INVALID_REMOTE_TIMESTAMP",
        responseShape: "invalid_timestamp",
      });
      return syncApiFailure("INVALID_REMOTE_TIMESTAMP", { status: 400, requestId });
    }
    if (blob.encrypted.version !== 1) {
      log({
        ok: false,
        errorCode: "UNSUPPORTED_ENCRYPTION_VERSION",
        responseShape: "unsupported_version",
      });
      return syncApiFailure("UNSUPPORTED_ENCRYPTION_VERSION", { status: 400, requestId });
    }
  }

  try {
    const report = await upsertEncryptedBlobs(
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
      blobCount: report.manifest.blobs.length,
      statusMatrix: report.statusMatrix,
    });

    return syncApiSuccess({
      manifest: report.manifest,
      statusMatrix: report.statusMatrix,
    });
  } catch (error) {
    log({
      ok: false,
      errorCode: "SYNC_PUSH_FAILED",
      responseShape: "error",
    });
    return syncApiFailure("SYNC_PUSH_FAILED", {
      status: 500,
      requestId,
      cause: error,
    });
  }
}
