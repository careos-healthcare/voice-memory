import "server-only";

import { dbQuery } from "@/lib/server/db";
import { assertAccountDeletionNotPending } from "@/lib/server/privacy/account-deletion-state";
import type { EncryptedPayload, SyncManifest } from "@/types/sync";
import type { StoredSyncBlob } from "@/lib/server/sync-store";

const FORBIDDEN_PLAINTEXT_KEYS = new Set([
  "transcript",
  "reflection",
  "audio",
  "audioId",
  "entries",
  "bookmarks",
  "settings",
  "memoryReviewLabels",
  "debugEvents",
  "plaintext",
  "text",
  "content",
]);

export function assertEncryptedPayloadOnly(payload: EncryptedPayload): void {
  if (!payload?.ciphertext || !payload?.iv || payload.version !== 1) {
    throw new Error("Invalid encrypted payload envelope.");
  }

  for (const key of Object.keys(payload as unknown as Record<string, unknown>)) {
    if (!["ciphertext", "iv", "version"].includes(key)) {
      throw new Error(`Unexpected encrypted payload field: ${key}`);
    }
  }
}

export function rejectPlaintextBlobFields(blob: Record<string, unknown>): void {
  for (const key of Object.keys(blob)) {
    if (FORBIDDEN_PLAINTEXT_KEYS.has(key)) {
      throw new Error(`Plaintext field rejected: ${key}`);
    }
  }
}

export async function upsertEncryptedBlobsPostgres(
  userId: string,
  blobs: StoredSyncBlob[],
): Promise<SyncManifest> {
  await assertAccountDeletionNotPending(userId);
  for (const blob of blobs) {
    rejectPlaintextBlobFields(blob as unknown as Record<string, unknown>);
    assertEncryptedPayloadOnly(blob.encrypted);

    await dbQuery(
      `INSERT INTO sync_blobs (
         user_id, blob_type, blob_id, encrypted_payload, updated_at,
         device_id, vector_clock, key_epoch
       )
       VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7::jsonb, $8)
       ON CONFLICT (user_id, blob_type, blob_id) DO UPDATE SET
         encrypted_payload = EXCLUDED.encrypted_payload,
         updated_at = EXCLUDED.updated_at,
         device_id = EXCLUDED.device_id,
         vector_clock = EXCLUDED.vector_clock,
         key_epoch = EXCLUDED.key_epoch`,
      [
        userId,
        blob.type,
        blob.id,
        JSON.stringify(blob.encrypted),
        blob.updatedAt,
        blob.deviceId ?? null,
        blob.vectorClock ? JSON.stringify(blob.vectorClock) : null,
        blob.keyEpoch ?? 1,
      ],
    );
  }

  return readSyncManifestPostgres(userId);
}

export async function readSyncManifestPostgres(userId: string): Promise<SyncManifest> {
  const result = await dbQuery<{
    blob_id: string;
    blob_type: string;
    updated_at: string;
    encrypted_payload: EncryptedPayload;
    device_id: string | null;
    vector_clock: Record<string, number> | null;
    key_epoch: number;
  }>(
    `SELECT blob_id, blob_type, updated_at, encrypted_payload,
            device_id, vector_clock, key_epoch
     FROM sync_blobs
     WHERE user_id = $1
     ORDER BY updated_at DESC`,
    [userId],
  );

  const blobs = result.rows.map((row) => ({
    id: row.blob_id,
    type: row.blob_type as StoredSyncBlob["type"],
    updatedAt: row.updated_at,
    byteLength: Buffer.byteLength(JSON.stringify(row.encrypted_payload), "utf8"),
  }));

  const updatedAt =
    blobs[0]?.updatedAt ??
    result.rows[0]?.updated_at ??
    new Date(0).toISOString();

  return {
    userId,
    version: blobs.length,
    updatedAt,
    blobs,
  };
}

export async function readEncryptedBlobsPostgres(userId: string): Promise<StoredSyncBlob[]> {
  const result = await dbQuery<{
    blob_id: string;
    blob_type: string;
    updated_at: string;
    encrypted_payload: EncryptedPayload;
    device_id: string | null;
    vector_clock: Record<string, number> | null;
    key_epoch: number;
  }>(
    `SELECT blob_id, blob_type, updated_at, encrypted_payload,
            device_id, vector_clock, key_epoch
     FROM sync_blobs
     WHERE user_id = $1
     ORDER BY updated_at DESC`,
    [userId],
  );

  return result.rows.map((row) => ({
    id: row.blob_id,
    type: row.blob_type as StoredSyncBlob["type"],
    encrypted: row.encrypted_payload,
    updatedAt: row.updated_at,
    byteLength: Buffer.byteLength(JSON.stringify(row.encrypted_payload), "utf8"),
    ...(row.device_id ? { deviceId: row.device_id } : {}),
    ...(row.vector_clock ? { vectorClock: row.vector_clock } : {}),
    keyEpoch: row.key_epoch,
  }));
}

export async function deleteEncryptedBlobsPostgres(userId: string): Promise<number> {
  const result = await dbQuery(`DELETE FROM sync_blobs WHERE user_id = $1`, [userId]);
  return result.rowCount ?? 0;
}
