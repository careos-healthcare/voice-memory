import { getUserById } from "@/lib/server/auth-store";
import { sessionExistsPostgres } from "@/lib/server/auth-store-postgres";
import { verifySessionToken } from "@/lib/server/auth-crypto";
import { shouldUsePostgresStorage } from "@/lib/server/db";
import { getServerSession, type ServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { purgeAccountSyncCopy } from "../../../../routes/sync/purge";

export const runtime = "nodejs";

const requestId = "sync-purge";

async function sessionFromBearer(request: Request): Promise<ServerSession | null> {
  const header = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(\S+)/i.exec(header);
  if (!match) return null;
  const token = match[1];
  const payload = verifySessionToken(token);
  if (!payload) return null;
  if (shouldUsePostgresStorage()) {
    const active = await sessionExistsPostgres(token);
    if (!active) return null;
  }
  const user = await getUserById(payload.userId);
  if (!user) return null;
  return { userId: user.id, email: user.email };
}

/** Deletes the signed-in account's encrypted server copy. */
export async function DELETE(request: Request) {
  const session = (await getServerSession()) ?? (await sessionFromBearer(request));
  if (!session) return syncApiUnauthorized(requestId);

  try {
    const purged = await purgeAccountSyncCopy(session.userId);
    return syncApiSuccess({
      purged: true,
      blobs: purged.blobs,
      mediaChunks: purged.mediaChunks,
      devices: purged.devices,
    });
  } catch (error) {
    return syncApiFailure("INTERNAL_ERROR", {
      status: 500,
      requestId,
      cause: error,
    });
  }
}
