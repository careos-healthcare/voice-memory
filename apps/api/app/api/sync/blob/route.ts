import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { presignBlobPut } from "@/lib/server/sync-records";

export const runtime = "nodejs";

/** Presigned PUT for one client-encrypted media chunk (4 MB). */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized("sync-blob");
  const body = (await request.json().catch(() => null)) as
    | { byteLength?: number; blobId?: string }
    | null;
  const byteLength = body?.byteLength ?? 0;
  const blobId = body?.blobId?.trim() || "";
  if (!blobId) {
    return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", { status: 400, requestId: "sync-blob" });
  }
  const signed = presignBlobPut({
    userId: session.userId,
    byteLength,
    blobId,
  });
  if (!signed.ok) {
    return syncApiFailure("SYNC_BLOB_TOO_LARGE", { status: signed.status, requestId: "sync-blob" });
  }
  return syncApiSuccess({
    blobId: signed.blobId,
    url: signed.url,
    method: signed.method,
    expiresInSeconds: signed.expiresInSeconds,
  });
}
