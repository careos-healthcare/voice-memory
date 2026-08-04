import { randomUUID } from "node:crypto";

import { getServerSession } from "@/lib/server/session";
import {
  syncApiFailure,
  syncApiUnauthorized,
} from "@/lib/server/sync-api-response";
import { hashEmailForLog } from "@/lib/server/auth-route-log";
import {
  createSyncRouteLog,
  readContentLength,
  summarizeBlobs,
} from "@/lib/server/sync-route-log";
import { readEncryptedBlobs } from "@/lib/server/sync-store";
import {
  serializeJsonBody,
  serializedJsonResponse,
} from "@/lib/server/serialized-json-response";
import { meterBestEffort } from "@/lib/server/unit-economics-meter";

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

  log({ emailHash: hashEmailForLog(session.email) });

  try {
    const blobs = (await readEncryptedBlobs(session.userId)).map((blob) => ({
      id: blob.id,
      type: blob.type,
      encrypted: blob.encrypted,
      updatedAt: blob.updatedAt,
      byteLength: blob.byteLength,
      ...(blob.deviceId ? { deviceId: blob.deviceId } : {}),
      ...(blob.vectorClock ? { vectorClock: blob.vectorClock } : {}),
      ...(blob.keyEpoch ? { keyEpoch: blob.keyEpoch } : {}),
    }));

    const summary = summarizeBlobs(blobs);
    log({
      ok: true,
      parseSuccess: true,
      responseShape: "blobs",
      ...summary,
    });

    const serialized = serializeJsonBody({ ok: true, blobs });
    const operationNonce = randomUUID();
    await Promise.all([
      meterBestEffort({
        operation: "sync.pull.egress",
        subject: { kind: "user", id: session.userId },
        idempotencyKey: operationNonce,
        metric: "egress_bytes",
        resource: "network.egress",
        quantity: serialized.bytes,
        measurementBasis: "exact",
      }),
      meterBestEffort({
        operation: "sync.pull.retrieval",
        subject: { kind: "user", id: session.userId },
        idempotencyKey: operationNonce,
        metric: "retrieval_bytes",
        resource: "network.retrieval",
        quantity: serialized.bytes,
        measurementBasis: "exact",
      }),
    ]);
    return serializedJsonResponse(serialized);
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
