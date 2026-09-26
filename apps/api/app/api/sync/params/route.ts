import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { syncRecordLedger } from "@/lib/server/sync-records";

export const runtime = "nodejs";

/** Argon2id salt and wrapping params for this account. No raw account key. */
export async function GET() {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized("sync-params");
  const params = syncRecordLedger(session.userId).readSyncParams();
  if (!params) {
    return syncApiFailure("SYNC_PARAMS_MISSING", {
      status: 404,
      requestId: "sync-params",
    });
  }
  return syncApiSuccess(params);
}
