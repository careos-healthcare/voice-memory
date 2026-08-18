import type { JournalEntry } from "@/types/journal";

const DB_NAME = "voicememory_journal";
const DB_VERSION = 1;
const STORE = "entries";
const MIGRATED_KEY = "voicememory_journal_idb_migrated";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error ?? new Error("IndexedDB open failed"));
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: "id" });
      }
    };
  });
}

export async function readJournalFromIndexedDb(): Promise<JournalEntry[] | null> {
  if (!isBrowser() || !("indexedDB" in window)) return null;
  try {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const store = tx.objectStore(STORE);
      const request = store.getAll();
      request.onsuccess = () => {
        const rows = (request.result ?? []) as JournalEntry[];
        resolve(
          rows.sort(
            (a, b) =>
              new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
          ),
        );
      };
      request.onerror = () => reject(request.error);
    });
  } catch {
    return null;
  }
}

export async function writeJournalToIndexedDb(entries: JournalEntry[]): Promise<boolean> {
  if (!isBrowser() || !("indexedDB" in window)) return false;
  try {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      const store = tx.objectStore(STORE);
      const clearReq = store.clear();
      clearReq.onsuccess = () => {
        for (const entry of entries) {
          store.put(entry);
        }
      };
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    return false;
  }
}

export async function migrateLocalStorageToIndexedDbIfNeeded(
  localStorageKey: string,
): Promise<void> {
  if (!isBrowser()) return;
  if (localStorage.getItem(MIGRATED_KEY) === "1") return;

  const raw = localStorage.getItem(localStorageKey);
  if (!raw) {
    localStorage.setItem(MIGRATED_KEY, "1");
    return;
  }

  try {
    const parsed = JSON.parse(raw) as JournalEntry[];
    if (Array.isArray(parsed) && parsed.length > 0) {
      await writeJournalToIndexedDb(parsed);
    }
    localStorage.setItem(MIGRATED_KEY, "1");
  } catch {
    // Keep localStorage as fallback; do not mark migrated on failure.
  }
}

export function estimateJournalBytes(entries: JournalEntry[]): number {
  try {
    return new Blob([JSON.stringify(entries)]).size;
  } catch {
    return 0;
  }
}

export const JOURNAL_QUOTA_WARN_BYTES = 4 * 1024 * 1024;

export async function clearJournalIndexedDb(): Promise<void> {
  if (!isBrowser() || !("indexedDB" in window)) return;
  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.objectStore(STORE).clear();
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    // ignore
  }
}
