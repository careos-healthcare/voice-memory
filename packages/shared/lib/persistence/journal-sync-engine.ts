/**
 * Signed-in journal sync — server-first with offline queue and conflict merge.
 */

import type { JournalEntry } from "@/types/journal";

const SYNC_STATUS_KEY = "voicememory_journal_sync_status";
const SYNC_QUEUE_KEY = "voicememory_journal_sync_queue";

export type ClientJournalSyncStatus =
  | "local_only"
  | "pending_sync"
  | "synced"
  | "sync_failed";

export function getClientJournalSyncStatus(): ClientJournalSyncStatus {
  if (typeof localStorage === "undefined") return "local_only";
  const v = localStorage.getItem(SYNC_STATUS_KEY);
  if (
    v === "synced" ||
    v === "sync_failed" ||
    v === "pending_sync" ||
    v === "local_only"
  ) {
    return v;
  }
  return "local_only";
}

export function setClientJournalSyncStatus(status: ClientJournalSyncStatus): void {
  if (typeof localStorage === "undefined") return;
  localStorage.setItem(SYNC_STATUS_KEY, status);
}

function readQueue(): JournalEntry[] {
  if (typeof localStorage === "undefined") return [];
  try {
    const raw = localStorage.getItem(SYNC_QUEUE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as JournalEntry[];
  } catch {
    return [];
  }
}

function writeQueue(entries: JournalEntry[]): void {
  if (typeof localStorage === "undefined") return;
  if (entries.length === 0) {
    localStorage.removeItem(SYNC_QUEUE_KEY);
    return;
  }
  localStorage.setItem(SYNC_QUEUE_KEY, JSON.stringify(entries));
}

export function mergeJournalByNewest(
  local: JournalEntry[],
  remote: JournalEntry[],
): JournalEntry[] {
  const map = new Map<string, JournalEntry>();
  for (const e of remote) map.set(e.id, e);
  for (const e of local) {
    const existing = map.get(e.id);
    if (!existing) {
      map.set(e.id, e);
      continue;
    }
    const localTs = new Date(e.createdAt).getTime();
    const remoteTs = new Date(existing.createdAt).getTime();
    if (localTs >= remoteTs) map.set(e.id, e);
  }
  return [...map.values()].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
}

export async function hasSignedInSession(): Promise<boolean> {
  try {
    const res = await fetch("/api/auth/session", { credentials: "include" });
    if (!res.ok) return false;
    const data = (await res.json()) as { session?: { user?: { id?: string } } | null };
    return Boolean(data.session?.user?.id);
  } catch {
    return false;
  }
}

export async function pushEntriesToServer(entries: JournalEntry[]): Promise<boolean> {
  if (entries.length === 0) return true;
  setClientJournalSyncStatus("pending_sync");
  try {
    const res = await fetch("/api/journal", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({ entries }),
    });
    if (!res.ok) {
      setClientJournalSyncStatus("sync_failed");
      return false;
    }
    setClientJournalSyncStatus("synced");
    return true;
  } catch {
    setClientJournalSyncStatus("sync_failed");
    return false;
  }
}

export async function pullEntriesFromServer(): Promise<JournalEntry[] | null> {
  try {
    const res = await fetch("/api/journal", { credentials: "include" });
    if (res.status === 401) return null;
    if (!res.ok) return null;
    const data = (await res.json()) as { entries?: JournalEntry[] };
    return data.entries ?? [];
  } catch {
    return null;
  }
}

/** Queue failed entry for retry; dedupe by id keeping newest createdAt. */
export function enqueueJournalSync(entry: JournalEntry): void {
  const queue = readQueue().filter((e) => e.id !== entry.id);
  queue.push(entry);
  writeQueue(queue);
  setClientJournalSyncStatus("pending_sync");
}

export async function flushJournalSyncQueue(): Promise<boolean> {
  const queue = readQueue();
  if (queue.length === 0) return true;
  const ok = await pushEntriesToServer(queue);
  if (ok) writeQueue([]);
  return ok;
}

/**
 * Server-first save when signed in: push entry, then rely on caller to persist local cache.
 */
export async function syncEntryServerFirst(entry: JournalEntry): Promise<{
  serverOk: boolean;
  signedIn: boolean;
}> {
  const signedIn = await hasSignedInSession();
  if (!signedIn) {
    setClientJournalSyncStatus("local_only");
    return { serverOk: false, signedIn: false };
  }

  const ok = await pushEntriesToServer([entry]);
  if (!ok) enqueueJournalSync(entry);
  return { serverOk: ok, signedIn: true };
}

export async function reconcileJournalWithServer(
  localEntries: JournalEntry[],
): Promise<JournalEntry[]> {
  const signedIn = await hasSignedInSession();
  if (!signedIn) {
    setClientJournalSyncStatus("local_only");
    return localEntries;
  }

  await flushJournalSyncQueue();
  const remote = await pullEntriesFromServer();
  if (!remote) {
    if (localEntries.length > 0) {
      setClientJournalSyncStatus("sync_failed");
      void pushEntriesToServer(localEntries);
    }
    return localEntries;
  }

  const merged = mergeJournalByNewest(localEntries, remote);
  setClientJournalSyncStatus("synced");
  if (merged.length > 0) {
    void pushEntriesToServer(merged);
  }
  return merged;
}
