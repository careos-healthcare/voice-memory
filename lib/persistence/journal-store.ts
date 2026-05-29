/**
 * Durable journal persistence — IndexedDB primary, localStorage sync cache.
 * Server-backed path remains encrypted sync (see lib/sync) when signed in.
 */

import { safeSetJson } from "@/lib/reliability/safe-local-storage";
import type { JournalEntry } from "@/types/journal";

import {
  estimateJournalBytes,
  JOURNAL_QUOTA_WARN_BYTES,
  migrateLocalStorageToIndexedDbIfNeeded,
  readJournalFromIndexedDb,
  writeJournalToIndexedDb,
} from "./journal-indexeddb";

const STORAGE_KEY = "voicememory_entries";

let hydratePromise: Promise<void> | null = null;
let lastQuotaWarnAt = 0;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getJournalStorageKey(): string {
  return STORAGE_KEY;
}

/** Hydrate localStorage cache from IndexedDB after migration. */
export async function ensureJournalPersistence(): Promise<void> {
  if (!isBrowser()) return;
  if (hydratePromise) return hydratePromise;

  hydratePromise = (async () => {
    await migrateLocalStorageToIndexedDbIfNeeded(STORAGE_KEY);
    const fromIdb = await readJournalFromIndexedDb();
    if (fromIdb && fromIdb.length > 0) {
      safeSetJson(STORAGE_KEY, fromIdb);
    }
  })();

  return hydratePromise;
}

export async function persistJournalDualWrite(entries: JournalEntry[]): Promise<{
  localOk: boolean;
  idbOk: boolean;
  quotaWarn: boolean;
}> {
  if (!isBrowser()) {
    return { localOk: false, idbOk: false, quotaWarn: false };
  }

  await ensureJournalPersistence();

  const bytes = estimateJournalBytes(entries);
  const quotaWarn = bytes > JOURNAL_QUOTA_WARN_BYTES;
  if (quotaWarn && Date.now() - lastQuotaWarnAt > 60_000) {
    lastQuotaWarnAt = Date.now();
    console.warn(
      `[VoiceMemory] Journal size ~${Math.round(bytes / 1024)}KB — export a backup soon.`,
    );
  }

  try {
    safeSetJson(STORAGE_KEY, entries);
  } catch {
    return { localOk: false, idbOk: false, quotaWarn };
  }
  const idbOk = await writeJournalToIndexedDb(entries);

  return { localOk: true, idbOk, quotaWarn };
}

export async function exportJournalSnapshot(): Promise<JournalEntry[]> {
  await ensureJournalPersistence();
  const fromIdb = await readJournalFromIndexedDb();
  if (fromIdb && fromIdb.length > 0) return fromIdb;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as JournalEntry[];
  } catch {
    return [];
  }
}
