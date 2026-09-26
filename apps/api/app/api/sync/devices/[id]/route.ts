import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { syncRecordLedger } from "@/lib/server/sync-records";

export const runtime = "nodejs";

const requestId = "sync-devices";

/** Drops the device refresh token and its key wrap. Records stay sealed. */
export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized(requestId);
  const { id } = await context.params;
  const deviceId = id.trim();
  if (!deviceId) {
    return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", { status: 400, requestId });
  }
  const removed = syncRecordLedger(session.userId).removeDevice(deviceId);
  if (!removed) {
    return syncApiFailure("DEVICE_NOT_FOUND", { status: 404, requestId });
  }
  return syncApiSuccess({ removed: deviceId });
}
