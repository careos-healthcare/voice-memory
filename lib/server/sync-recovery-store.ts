import "server-only";

import path from "node:path";

import { createHash } from "node:crypto";
import { dbQuery, shouldUseFilesystemStorage, shouldUsePostgresStorage } from "@/lib/server/db";
import { ensureDataDir, readJsonFile, writeJsonFile } from "@/lib/server/data-path";
import {
  decideSyncRecoveryUpsert,
  type SyncRecoveryEnvelopeRecord,
} from "@/lib/sync/recovery-envelope-contract";

export type { SyncRecoveryEnvelopeRecord } from "@/lib/sync/recovery-envelope-contract";

interface StoredRecovery {
  envelope: SyncRecoveryEnvelopeRecord;
  digest: string;
}

const globalRecovery = globalThis as typeof globalThis & {
  __archiveMeSyncRecovery?: Record<string, StoredRecovery>;
};

function digest(envelope: SyncRecoveryEnvelopeRecord): string {
  const canonical = [
    envelope.schemaVersion,
    envelope.kdf,
    envelope.kdfIterations,
    envelope.algorithm,
    envelope.ownerAccountId,
    envelope.ownerArchiveId,
    envelope.keyEpoch,
    envelope.envelopeRevision,
    envelope.salt,
    envelope.nonce,
    envelope.ciphertext,
    envelope.mac,
    envelope.createdAt,
    envelope.updatedAt,
  ];
  return createHash("sha256")
    .update(JSON.stringify(canonical))
    .digest("base64url");
}

function filePath(userId: string): string {
  const safeUser = createHash("sha256").update(userId).digest("hex");
  return path.join(ensureDataDir("sync-recovery"), `${safeUser}.json`);
}

export async function readSyncRecovery(
  userId: string,
): Promise<SyncRecoveryEnvelopeRecord | null> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{ envelope: SyncRecoveryEnvelopeRecord }>(
      `SELECT envelope FROM sync_recovery_envelopes WHERE user_id = $1`,
      [userId],
    );
    return result.rows[0]?.envelope ?? null;
  }
  if (shouldUseFilesystemStorage()) {
    return readJsonFile<StoredRecovery | null>(filePath(userId), null)?.envelope ?? null;
  }
  return globalRecovery.__archiveMeSyncRecovery?.[userId]?.envelope ?? null;
}

/**
 * Idempotent for an identical revision and rejects stale or conflicting
 * revisions, preventing a captured old envelope from replacing the current one.
 */
export async function upsertSyncRecovery(
  userId: string,
  envelope: SyncRecoveryEnvelopeRecord,
): Promise<"created" | "updated" | "unchanged"> {
  const nextDigest = digest(envelope);
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      envelope_revision: number;
      envelope_digest: string;
    }>(
      `SELECT envelope_revision, envelope_digest
       FROM sync_recovery_envelopes WHERE user_id = $1`,
      [userId],
    );
    const current = result.rows[0];
    const decision = decideSyncRecoveryUpsert(
      current
        ? {
            envelopeRevision: current.envelope_revision,
            digest: current.envelope_digest,
          }
        : null,
      { envelopeRevision: envelope.envelopeRevision, digest: nextDigest },
    );
    if (decision === "unchanged") {
      return decision;
    }
    await dbQuery(
      `INSERT INTO sync_recovery_envelopes (
         user_id, owner_archive_id, key_epoch, envelope_revision,
         envelope, envelope_digest, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8)
       ON CONFLICT (user_id) DO UPDATE SET
         owner_archive_id = EXCLUDED.owner_archive_id,
         key_epoch = EXCLUDED.key_epoch,
         envelope_revision = EXCLUDED.envelope_revision,
         envelope = EXCLUDED.envelope,
         envelope_digest = EXCLUDED.envelope_digest,
         updated_at = EXCLUDED.updated_at`,
      [
        userId,
        envelope.ownerArchiveId,
        envelope.keyEpoch,
        envelope.envelopeRevision,
        JSON.stringify(envelope),
        nextDigest,
        envelope.createdAt,
        envelope.updatedAt,
      ],
    );
    return decision;
  }

  const current = shouldUseFilesystemStorage()
    ? readJsonFile<StoredRecovery | null>(filePath(userId), null)
    : globalRecovery.__archiveMeSyncRecovery?.[userId] ?? null;
  const decision = decideSyncRecoveryUpsert(
    current
      ? {
          envelopeRevision: current.envelope.envelopeRevision,
          digest: current.digest,
        }
      : null,
    { envelopeRevision: envelope.envelopeRevision, digest: nextDigest },
  );
  if (decision === "unchanged") {
    return decision;
  }
  const stored = { envelope, digest: nextDigest };
  if (shouldUseFilesystemStorage()) {
    writeJsonFile(filePath(userId), stored);
  } else {
    globalRecovery.__archiveMeSyncRecovery ??= {};
    globalRecovery.__archiveMeSyncRecovery[userId] = stored;
  }
  return decision;
}

export async function deleteSyncRecovery(userId: string): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await dbQuery(`DELETE FROM sync_recovery_envelopes WHERE user_id = $1`, [userId]);
    return;
  }
  if (shouldUseFilesystemStorage()) {
    writeJsonFile(filePath(userId), null);
    return;
  }
  if (globalRecovery.__archiveMeSyncRecovery) {
    delete globalRecovery.__archiveMeSyncRecovery[userId];
  }
}

export async function syncRecoveryExists(userId: string): Promise<boolean> {
  return (await readSyncRecovery(userId)) !== null;
}

export function resetSyncRecoveryMemoryStoreForTests(): void {
  globalRecovery.__archiveMeSyncRecovery = {};
}
