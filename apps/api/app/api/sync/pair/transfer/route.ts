import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiSuccess,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { syncRecordLedger } from "@/lib/server/sync-records";

export const runtime = "nodejs";

const requestId = "sync-pair-transfer";
const forbiddenKeys = ["accountKey", "masterKey", "wrap", "plaintext", "transcript", "text"] as const;

/** Existing device posts an ECDH-sealed account key. The QR never carries it. */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized(requestId);
  const body = (await request.json().catch(() => null)) as Record<string, unknown> | null;
  if (!body) {
    return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", { status: 400, requestId });
  }
  if (forbiddenKeys.some((key) => body[key] != null)) {
    return syncApiFailure("PLAINTEXT_NOT_ACCEPTED", { status: 400, requestId });
  }
  const id = typeof body.id === "string" ? body.id.trim() : "";
  const ciphertext = typeof body.ciphertext === "string" ? body.ciphertext.trim() : "";
  const nonce = typeof body.nonce === "string" ? body.nonce.trim() : "";
  const senderPublicKey =
    typeof body.senderPublicKey === "string" ? body.senderPublicKey.trim() : "";
  if (!id || !ciphertext || !nonce || !senderPublicKey) {
    return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", { status: 400, requestId });
  }
  const stored = syncRecordLedger(session.userId).putRelay(
    id,
    ciphertext,
    nonce,
    senderPublicKey,
  );
  return syncApiSuccess({ id: stored.id, expiresAt: stored.expiresAt });
}

/** New device claims the sealed payload for the id shown in its QR code. */
export async function GET(request: Request) {
  const session = await getServerSession();
  if (!session) return syncApiUnauthorized(requestId);
  const id = new URL(request.url).searchParams.get("id")?.trim() ?? "";
  if (!id) {
    return syncApiFailure("INVALID_ENCRYPTED_ENVELOPE", { status: 400, requestId });
  }
  const claimed = syncRecordLedger(session.userId).claimRelay(id);
  if (!claimed.ok) {
    return syncApiFailure("PAIRING_EXPIRED", { status: 404, requestId });
  }
  return syncApiSuccess({
    ciphertext: claimed.ciphertext,
    nonce: claimed.nonce,
    senderPublicKey: claimed.senderPublicKey,
  });
}
