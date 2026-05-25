import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import {
  createSyncRouteLog,
  readContentLength,
} from "@/lib/server/sync-route-log";
import { readSyncManifest } from "@/lib/server/sync-store";

export const runtime = "nodejs";

/** Metadata only — ciphertext sizes and timestamps, never plaintext. */
export async function GET(request: Request) {
  const { log } = createSyncRouteLog("manifest", "GET");
  log({
    contentLength: readContentLength(request),
    bodyPresent: false,
  });

  const session = await getServerSession();
  if (!session) {
    log({ ok: false, errorCode: "SYNC_AUTH_REQUIRED", responseShape: "auth_required" });
    return syncApiUnauthorized();
  }

  log({ email: session.email });

  try {
    const manifest = readSyncManifest(session.userId);
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
    return syncApiFailure(
      error instanceof Error ? error.message : "Could not read sync manifest.",
      "SYNC_MANIFEST_FAILED",
      500,
    );
  }
}
