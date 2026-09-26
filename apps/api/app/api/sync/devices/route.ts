import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { syncRecordLedger } from "@/lib/server/sync-records";

export const runtime = "nodejs";

const requestId = "sync-devices";

/** Phones that hold a sync token for this account. */
export async function GET() {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized(requestId);
  return syncApiSuccess({
    devices: syncRecordLedger(session.userId).listDevices(),
  });
}

/** Records this phone so the device list can show it. */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized(requestId);
  const body = (await request.json().catch(() => null)) as
    | { id?: string; name?: string; platform?: string }
    | null;
  const id = body?.id?.trim() ?? "";
  if (!id) {
    return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", { status: 400, requestId });
  }
  const device = syncRecordLedger(session.userId).registerDevice({
    id,
    name: body?.name ?? "",
    platform: body?.platform ?? "",
  });
  if (!device) {
    return syncApiFailure("DEVICE_REVOKED", { status: 401, requestId });
  }
  return syncApiSuccess({ device });
}
