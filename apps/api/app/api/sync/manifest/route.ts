import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { hashEmailForLog } from "@/lib/server/auth-route-log";
import {
  createSyncRouteLog,
  readContentLength,
} from "@/lib/server/sync-route-log";
import { readSyncManifest } from "@/lib/server/sync-store";

export const runtime = "nodejs";

/** Metadata only — ciphertext sizes and timestamps, never plaintext. */
export async function GET(request: Request) {
  const { requestId, log } = createSyncRouteLog("manifest", "GET");
  log({
    contentLength: readContentLength(request),
    bodyPresent: false,
  });

  const session = await getServerSession();
  if (!session) {
    log({ ok: false, errorCode: "SYNC_AUTH_REQUIRED", responseShape: "auth_required" });
    return syncApiUnauthorized(requestId);
  }

  log({ emailHash: hashEmailForLog(session.email) });

  try {
    const manifest = await readSyncManifest(session.userId);
    log({
      ok: true,
      parseSuccess: true,
      responseShape: "manifest",
      blobCount: manifest.blobs.length,
      blobIds: manifest.blobs.map((blob) => blob.id).slice(0, 12),
      encryptionVersions: [],
    });
    return syncApiSuccess({ manifest });
  } catch (error) {
    log({
      ok: false,
      errorCode: "SYNC_MANIFEST_FAILED",
      responseShape: "error",
    });
    return syncApiFailure("SYNC_MANIFEST_FAILED", {
      status: 500,
      requestId,
      cause: error,
    });
  }
}
