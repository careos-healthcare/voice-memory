import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import {
  compareJournalRevisions,
  deriveJournalSyncMetadata,
} from "@/lib/server/journal-sync-compare";
import type { JournalEntry } from "@/types/journal";

export type JournalSyncStatus = "local_only" | "synced" | "sync_failed";

export interface ServerJournalRow {
  entryId: string;
  payload: JournalEntry;
  syncStatus: JournalSyncStatus;
  clientUpdatedAt: string;
  updatedAt: string;
}

/** Maximum number of entries accepted per bulk sync request (`POST /api/journal`). */
export const JOURNAL_SYNC_BATCH_LIMIT = 200;

/** Sane cap on a single serialized journal entry — guards against pathological payloads. */
export const JOURNAL_ENTRY_MAX_BYTES = 200 * 1024;

/**
 * Fields a client could embed in an entry payload to try to spoof ownership.
 * Storage is always keyed strictly by `session.userId` from `getServerSession()` —
 * these are stripped defensively before an entry is ever persisted or compared,
 * regardless of whether the current payload type declares them.
 */
const SPOOFABLE_OWNERSHIP_KEYS = [
  "userId",
  "user_id",
  "ownerId",
  "owner_id",
  "accountId",
  "account_id",
  "session",
  "sessionUserId",
];

export type JournalEntryRejectionCode =
  | "INVALID_ENTRY"
  | "MISSING_ID"
  | "INVALID_CREATED_AT"
  | "INVALID_REVISION"
  | "PAYLOAD_TOO_LARGE"
  | "STALE_REVISION";

export interface JournalEntryRejection {
  id: string;
  reason: JournalEntryRejectionCode;
  message: string;
  /** The server's current winning payload — present whenever a conflict (not a shape error) caused rejection. */
  winning?: JournalEntry;
}

export interface JournalSyncPushReport {
  accepted: string[];
  rejected: JournalEntryRejection[];
}

const memoryJournal = globalThis as typeof globalThis & {
  __vmJournal?: Map<string, Map<string, ServerJournalRow>>;
};

function userMap(userId: string): Map<string, ServerJournalRow> {
  if (!memoryJournal.__vmJournal) memoryJournal.__vmJournal = new Map();
  let map = memoryJournal.__vmJournal.get(userId);
  if (!map) {
    map = new Map();
    memoryJournal.__vmJournal.set(userId, map);
  }
  return map;
}

/**
 * The non-Postgres branch of this store is always an in-memory map — there is
 * no filesystem-backed journal persistence today, even in local dev. Reported
 * separately from `lib/server/db.ts`'s generic filesystem/memory split so the
 * account-deletion contract can report the true storage mode honestly.
 */
export function currentJournalStorageMode(): "postgres" | "memory" {
  return shouldUsePostgresStorage() ? "postgres" : "memory";
}

export async function listServerJournalEntries(userId: string): Promise<ServerJournalRow[]> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      entry_id: string;
      payload: JournalEntry;
      sync_status: JournalSyncStatus;
      client_updated_at: Date;
      updated_at: Date;
    }>(
      `SELECT entry_id, payload, sync_status, client_updated_at, updated_at
       FROM journal_entries
       WHERE user_id = $1
       ORDER BY client_updated_at DESC`,
      [userId],
    );
    return result.rows.map((row) => ({
      entryId: row.entry_id,
      payload: row.payload,
      syncStatus: row.sync_status,
      clientUpdatedAt: row.client_updated_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    }));
  }
  return [...userMap(userId).values()].sort(
    (a, b) => b.clientUpdatedAt.localeCompare(a.clientUpdatedAt),
  );
}

/** Single-row lookup used by the conditional-upsert conflict check. */
export async function getServerJournalEntry(
  userId: string,
  entryId: string,
): Promise<ServerJournalRow | null> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      entry_id: string;
      payload: JournalEntry;
      sync_status: JournalSyncStatus;
      client_updated_at: Date;
      updated_at: Date;
    }>(
      `SELECT entry_id, payload, sync_status, client_updated_at, updated_at
       FROM journal_entries
       WHERE user_id = $1 AND entry_id = $2`,
      [userId, entryId],
    );
    const row = result.rows[0];
    if (!row) return null;
    return {
      entryId: row.entry_id,
      payload: row.payload,
      syncStatus: row.sync_status,
      clientUpdatedAt: row.client_updated_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  }
  return userMap(userId).get(entryId) ?? null;
}

async function writeServerJournalRow(
  userId: string,
  entry: JournalEntry,
  status: JournalSyncStatus,
): Promise<void> {
  const clientUpdatedAt = entry.updatedAt ?? entry.createdAt;

  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO journal_entries (user_id, entry_id, payload, sync_status, client_updated_at, updated_at)
       VALUES ($1, $2, $3::jsonb, $4, $5, now())
       ON CONFLICT (user_id, entry_id) DO UPDATE SET
         payload = EXCLUDED.payload,
         sync_status = EXCLUDED.sync_status,
         client_updated_at = EXCLUDED.client_updated_at,
         updated_at = now()`,
      [userId, entry.id, JSON.stringify(entry), status, clientUpdatedAt],
    );
    return;
  }

  userMap(userId).set(entry.id, {
    entryId: entry.id,
    payload: entry,
    syncStatus: status,
    clientUpdatedAt,
    updatedAt: new Date().toISOString(),
  });
}

/**
 * Unconditional, force-overwrite upsert — last write wins, no conflict
 * resolution. Used internally (proof/health checks, non-sync test fixtures)
 * where callers explicitly want a plain write, not the sync-conflict path.
 * Ordinary client sync traffic must go through
 * `upsertServerJournalEntriesConditional` instead.
 */
export async function upsertServerJournalEntries(
  userId: string,
  entries: Array<{ entry: JournalEntry; syncStatus?: JournalSyncStatus }>,
): Promise<{ upserted: number }> {
  let upserted = 0;
  for (const item of entries) {
    await writeServerJournalRow(userId, item.entry, item.syncStatus ?? "synced");
    upserted += 1;
  }
  return { upserted };
}

function stripSpoofedOwnershipFields(raw: Record<string, unknown>): Record<string, unknown> {
  const clone = { ...raw };
  for (const key of SPOOFABLE_OWNERSHIP_KEYS) {
    delete clone[key];
  }
  return clone;
}

function validateIncomingJournalEntryShape(
  raw: Record<string, unknown>,
): JournalEntryRejection | null {
  const id = typeof raw.id === "string" ? raw.id.trim() : "";
  if (!id) {
    return { id: "unknown", reason: "MISSING_ID", message: "Entry id is required." };
  }

  const createdAt = raw.createdAt;
  if (typeof createdAt !== "string" || Number.isNaN(Date.parse(createdAt))) {
    return {
      id,
      reason: "INVALID_CREATED_AT",
      message: "createdAt must be a valid ISO date string.",
    };
  }

  if (
    raw.revision !== undefined &&
    (typeof raw.revision !== "number" ||
      !Number.isInteger(raw.revision) ||
      raw.revision < 1)
  ) {
    return {
      id,
      reason: "INVALID_REVISION",
      message: "revision must be a positive integer.",
    };
  }

  const size = Buffer.byteLength(JSON.stringify(raw), "utf8");
  if (size > JOURNAL_ENTRY_MAX_BYTES) {
    return {
      id,
      reason: "PAYLOAD_TOO_LARGE",
      message: `Entry exceeds the ${JOURNAL_ENTRY_MAX_BYTES}-byte limit.`,
    };
  }

  return null;
}

/**
 * Conditional (conflict-aware) upsert — this is the path ordinary client
 * sync traffic goes through (bulk `POST /api/journal` and single-entry
 * `PUT /api/journal/[id]`).
 *
 * For each incoming entry:
 *   1. Ownership-spoofing fields are stripped (storage stays keyed by `userId`).
 *   2. Shape is validated (id, createdAt, revision, payload size).
 *   3. Legacy sync metadata (updatedAt/revision/changeId/schemaVersion) is
 *      defaulted for pre-migration clients.
 *   4. If a row already exists for (userId, entryId), the incoming entry must
 *      strictly beat it per `compareJournalRevisions` to be written — ties and
 *      losses are rejected with the server's current winning payload attached
 *      so the client can reconcile locally. A tombstone (`deletedAt` set) is
 *      just another revision and goes through the exact same comparison.
 *
 * A single bad/losing entry never fails the rest of the batch.
 */
export async function upsertServerJournalEntriesConditional(
  userId: string,
  rawEntries: unknown[],
): Promise<JournalSyncPushReport> {
  const accepted: string[] = [];
  const rejected: JournalEntryRejection[] = [];

  for (const rawInput of rawEntries) {
    if (!rawInput || typeof rawInput !== "object") {
      rejected.push({
        id: "unknown",
        reason: "INVALID_ENTRY",
        message: "Entry must be an object.",
      });
      continue;
    }

    const sanitized = stripSpoofedOwnershipFields(rawInput as Record<string, unknown>);
    const shapeError = validateIncomingJournalEntryShape(sanitized);
    if (shapeError) {
      rejected.push(shapeError);
      continue;
    }

    const candidateEntry = sanitized as unknown as JournalEntry;
    const candidateMeta = deriveJournalSyncMetadata(candidateEntry);
    const candidate: JournalEntry = { ...candidateEntry, ...candidateMeta };

    const existingRow = await getServerJournalEntry(userId, candidate.id);
    if (existingRow) {
      const existingMeta = deriveJournalSyncMetadata(existingRow.payload);
      const existing: JournalEntry = { ...existingRow.payload, ...existingMeta };
      const cmp = compareJournalRevisions(candidateMeta, existingMeta);
      if (cmp <= 0) {
        rejected.push({
          id: candidate.id,
          reason: "STALE_REVISION",
          message:
            cmp === 0
              ? "An identical-or-equal revision already exists on the server."
              : "A newer revision already exists on the server.",
          winning: existing,
        });
        continue;
      }
    }

    await writeServerJournalRow(userId, candidate, "synced");
    accepted.push(candidate.id);
  }

  return { accepted, rejected };
}

export async function deleteServerJournalEntry(
  userId: string,
  entryId: string,
): Promise<boolean> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery(
      `DELETE FROM journal_entries WHERE user_id = $1 AND entry_id = $2`,
      [userId, entryId],
    );
    return (result.rowCount ?? 0) > 0;
  }
  return userMap(userId).delete(entryId);
}

export async function deleteAllServerJournalEntries(userId: string): Promise<number> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery(`DELETE FROM journal_entries WHERE user_id = $1`, [userId]);
    return result.rowCount ?? 0;
  }
  const map = userMap(userId);
  const count = map.size;
  map.clear();
  return count;
}

export async function exportServerJournal(userId: string): Promise<JournalEntry[]> {
  const rows = await listServerJournalEntries(userId);
  return rows.map((r) => r.payload);
}
