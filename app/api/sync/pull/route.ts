import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import {
  createSyncRouteLog,
  readContentLength,
  summarizeBlobs,
} from "@/lib/server/sync-route-log";
import { readEncryptedBlobs } from "@/lib/server/sync-store";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const { log } = createSyncRouteLog("pull", "GET");
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
    const blobs = readEncryptedBlobs(session.userId).map((blob) => ({
      id: blob.id,
      type: blob.type,
      encrypted: blob.encrypted,
      updatedAt: blob.updatedAt,
      byteLength: blob.byteLength,
    }));

    const summary = summarizeBlobs(blobs);
    log({
      ok: true,
      parseSuccess: true,
      responseShape: "blobs",
      ...summary,
    });

    return syncApiSuccess({ blobs });
  } catch (error) {
    log({
      ok: false,
      errorCode: "SYNC_PULL_FAILED",
      responseShape: "error",
    });
    return syncApiFailure(
      error instanceof Error ? error.message : "Could not read encrypted backup.",
      "SYNC_PULL_FAILED",
      500,
    );
  }
}
