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
import { readSyncChangesSince } from "@/lib/server/sync-store";

export const runtime = "nodejs";

/** Incremental encrypted sync — metadata + ciphertext for blobs changed since [since]. */
export async function GET(request: Request) {
  const { requestId, log } = createSyncRouteLog("changes", "GET");
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

  const url = new URL(request.url);
  const sinceRaw = url.searchParams.get("since") ?? "0";
  const sinceSequence = Number(sinceRaw);
  if (!Number.isFinite(sinceSequence) || sinceSequence < 0) {
    log({
      ok: false,
      errorCode: "INVALID_SYNC_CURSOR",
      responseShape: "invalid_cursor",
    });
    return syncApiFailure("INVALID_SYNC_CURSOR", { status: 400, requestId });
  }

  try {
    const payload = await readSyncChangesSince(session.userId, sinceSequence);
    log({
      ok: true,
      parseSuccess: true,
      responseShape: "changes",
      blobCount: payload.blobs.length,
      changeCount: payload.changes.length,
    });
    return syncApiSuccess(payload as unknown as Record<string, unknown>);
  } catch (error) {
    log({
      ok: false,
      errorCode: "SYNC_CHANGES_FAILED",
      responseShape: "error",
    });
    return syncApiFailure("SYNC_CHANGES_FAILED", {
      status: 500,
      requestId,
      cause: error,
    });
  }
}
