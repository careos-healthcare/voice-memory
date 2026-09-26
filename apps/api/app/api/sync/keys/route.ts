import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { syncRecordLedger } from "@/lib/server/sync-records";

export const runtime = "nodejs";

/** Stores and returns wrapped account keys. Plaintext keys are rejected. */
export async function GET() {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized("sync-keys");
  return syncApiSuccess({
    keys: syncRecordLedger(session.userId).readKeys(),
  });
}

export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized("sync-keys");
  const body = (await request.json().catch(() => null)) as
    | {
        wrappedByPassphrase?: unknown;
        wrappedByRecovery?: unknown;
        kdfParams?: unknown;
        createdAt?: string;
        accountKey?: unknown;
      }
    | null;
  if (!body?.wrappedByPassphrase || !body.wrappedByRecovery || !body.kdfParams) {
    return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", {
      status: 400,
      requestId: "sync-keys",
    });
  }
  if (body.accountKey != null) {
    return syncApiFailure("PLAINTEXT_NOT_ACCEPTED", {
      status: 400,
      requestId: "sync-keys",
    });
  }
  const keys = syncRecordLedger(session.userId).storeKeys(body);
  return syncApiSuccess({ keys });
}

export async function DELETE(request: Request) {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized("sync-keys");
  const url = new URL(request.url);
  const deviceId = url.searchParams.get("deviceId")?.trim() ?? "";
  if (!deviceId) {
    return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", {
      status: 400,
      requestId: "sync-keys",
    });
  }
  syncRecordLedger(session.userId).revokeDevice(deviceId);
  return syncApiSuccess({ removed: deviceId });
}
