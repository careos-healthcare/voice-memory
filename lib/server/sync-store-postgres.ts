import "server-only";

import { dbQuery } from "@/lib/server/db";
import type { EncryptedPayload, SyncChangeRecord, SyncChangesResponse, SyncManifest } from "@/types/sync";
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
  for (const blob of blobs) {
    rejectPlaintextBlobFields(blob as unknown as Record<string, unknown>);
    assertEncryptedPayloadOnly(blob.encrypted);

    await dbQuery(
      `INSERT INTO sync_blobs (user_id, blob_type, blob_id, encrypted_payload, updated_at)
       VALUES ($1, $2, $3, $4::jsonb, $5)
       ON CONFLICT (user_id, blob_type, blob_id) DO UPDATE SET
         encrypted_payload = EXCLUDED.encrypted_payload,
         updated_at = EXCLUDED.updated_at`,
      [
        userId,
        blob.type,
        blob.id,
        JSON.stringify(blob.encrypted),
        blob.updatedAt,
      ],
    );

    const sequenceResult = await dbQuery<{ next_sequence: string }>(
      `INSERT INTO sync_change_log (user_id, sequence, blob_type, blob_id, change_kind, updated_at, tombstone)
       VALUES (
         $1,
         COALESCE((SELECT MAX(sequence) FROM sync_change_log WHERE user_id = $1), 0) + 1,
         $2,
         $3,
         'upsert',
         $4,
         false
       )
       RETURNING sequence AS next_sequence`,
      [userId, blob.type, blob.id, blob.updatedAt],
    );
    void sequenceResult;
  }

  return readSyncManifestPostgres(userId);
}

export async function readSyncManifestPostgres(userId: string): Promise<SyncManifest> {
  const result = await dbQuery<{
    blob_id: string;
    blob_type: string;
    updated_at: string;
    encrypted_payload: EncryptedPayload;
  }>(
    `SELECT blob_id, blob_type, updated_at, encrypted_payload
     FROM sync_blobs
     WHERE user_id = $1
     ORDER BY updated_at DESC`,
    [userId],
  );

  const sequenceResult = await dbQuery<{ latest_sequence: string | null }>(
    `SELECT MAX(sequence) AS latest_sequence FROM sync_change_log WHERE user_id = $1`,
    [userId],
  );
  const latestSequence = Number(sequenceResult.rows[0]?.latest_sequence ?? 0);

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
    latestSequence,
    blobs,
  };
}

export async function readSyncChangesSincePostgres(
  userId: string,
  sinceSequence: number,
): Promise<SyncChangesResponse> {
  const changesResult = await dbQuery<{
    sequence: string;
    blob_type: string;
    blob_id: string;
    change_kind: string;
    updated_at: string;
    tombstone: boolean;
  }>(
    `SELECT sequence, blob_type, blob_id, change_kind, updated_at, tombstone
     FROM sync_change_log
     WHERE user_id = $1 AND sequence > $2
     ORDER BY sequence ASC`,
    [userId, sinceSequence],
  );

  const changes: SyncChangeRecord[] = changesResult.rows.map((row) => ({
    sequence: Number(row.sequence),
    blobType: row.blob_type as StoredSyncBlob["type"],
    blobId: row.blob_id,
    changeKind: row.change_kind === "delete" ? "delete" : "upsert",
    updatedAt: row.updated_at,
    tombstone: row.tombstone,
  }));

  const latestSequence =
    changes.length > 0
      ? changes[changes.length - 1]!.sequence
      : Number(
          (
            await dbQuery<{ latest_sequence: string | null }>(
              `SELECT MAX(sequence) AS latest_sequence FROM sync_change_log WHERE user_id = $1`,
              [userId],
            )
          ).rows[0]?.latest_sequence ?? sinceSequence,
        );

  const blobIds = [...new Set(changes.map((change) => change.blobId))];
  if (blobIds.length === 0) {
    return { latestSequence, changes: [], blobs: [] };
  }

  const blobsResult = await dbQuery<{
    blob_id: string;
    blob_type: string;
    updated_at: string;
    encrypted_payload: EncryptedPayload;
  }>(
    `SELECT blob_id, blob_type, updated_at, encrypted_payload
     FROM sync_blobs
     WHERE user_id = $1 AND blob_id = ANY($2::text[])`,
    [userId, blobIds],
  );

  return {
    latestSequence,
    changes,
    blobs: blobsResult.rows.map((row) => ({
      id: row.blob_id,
      type: row.blob_type as StoredSyncBlob["type"],
      encrypted: row.encrypted_payload,
      updatedAt: row.updated_at,
      byteLength: Buffer.byteLength(JSON.stringify(row.encrypted_payload), "utf8"),
    })),
  };
}

export async function deleteSyncBlobsForUserPostgres(userId: string): Promise<number> {
  const result = await dbQuery(`DELETE FROM sync_blobs WHERE user_id = $1`, [userId]);
  return result.rowCount ?? 0;
}

export async function readEncryptedBlobsPostgres(userId: string): Promise<StoredSyncBlob[]> {
  const result = await dbQuery<{
    blob_id: string;
    blob_type: string;
    updated_at: string;
    encrypted_payload: EncryptedPayload;
  }>(
    `SELECT blob_id, blob_type, updated_at, encrypted_payload
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
  }));
}
