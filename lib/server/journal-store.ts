import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { assertAccountDeletionNotPending } from "@/lib/server/privacy/account-deletion-state";
import type { JournalEntry } from "@/types/journal";

export type JournalSyncStatus = "local_only" | "synced" | "sync_failed";

export interface ServerJournalRow {
  entryId: string;
  payload: JournalEntry;
  syncStatus: JournalSyncStatus;
  clientUpdatedAt: string;
  updatedAt: string;
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

export async function upsertServerJournalEntries(
  userId: string,
  entries: Array<{ entry: JournalEntry; syncStatus?: JournalSyncStatus }>,
): Promise<{ upserted: number }> {
  await assertAccountDeletionNotPending(userId);
  let upserted = 0;
  for (const item of entries) {
    const status = item.syncStatus ?? "synced";
    const clientUpdatedAt = item.entry.createdAt;

    if (shouldUsePostgresStorage()) {
      await dbQuery(
        `INSERT INTO journal_entries (user_id, entry_id, payload, sync_status, client_updated_at, updated_at)
         VALUES ($1, $2, $3::jsonb, $4, $5, now())
         ON CONFLICT (user_id, entry_id) DO UPDATE SET
           payload = EXCLUDED.payload,
           sync_status = EXCLUDED.sync_status,
           client_updated_at = EXCLUDED.client_updated_at,
           updated_at = now()`,
        [userId, item.entry.id, JSON.stringify(item.entry), status, clientUpdatedAt],
      );
      upserted += 1;
      continue;
    }

    userMap(userId).set(item.entry.id, {
      entryId: item.entry.id,
      payload: item.entry,
      syncStatus: status,
      clientUpdatedAt,
      updatedAt: new Date().toISOString(),
    });
    upserted += 1;
  }
  return { upserted };
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
