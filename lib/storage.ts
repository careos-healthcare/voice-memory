import { deleteAudio } from "@/lib/audio-storage";
import { deleteAtmosphereImage } from "@/lib/atmosphere/atmosphere-storage";
import { deletePhoto } from "@/lib/photo-storage";
import { clearHabitState } from "@/lib/habit-storage";
import { recordReflectionDay } from "@/lib/habit-storage";
import { trackReflectionMilestones } from "@/lib/local-analytics";
import { bumpTimingFromEntry } from "@/lib/refinement/emotional-timing";
import { trackMoatNewReflection } from "@/lib/retention/moat-metrics";
import { removeBookmark } from "@/lib/reflection-bookmarks";
import { normalizeReflection } from "@/lib/reflection";
import { ensureStorageReady } from "@/lib/reliability/migrations";
import { safeSetJson } from "@/lib/reliability/safe-local-storage";
import { bumpPhraseScanCache } from "@/lib/performance/phrase-scan-cache";
import { clearResurfacingCaches } from "@/lib/performance/resurfacing-cache";
import { FREE_ENTRY_LIMIT, isProUser } from "@/lib/subscription";
import type { JournalEntry, Reflection } from "@/types/journal";

const STORAGE_KEY = "voicememory_entries";

let memoryEligibleVersion = 0;
let memoryEligibleCache: JournalEntry[] = [];
let memoryEligibleCachedVersion = -1;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function loadAllEntries(): JournalEntry[] {
  if (!isBrowser()) return [];

  ensureStorageReady();

  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];

    const parsed = JSON.parse(raw) as JournalEntry[];
    return parsed
      .map((entry) => ({
        ...entry,
        reflection: normalizeReflection(entry.reflection as Reflection),
      }))
      .sort(
        (a, b) =>
          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      );
  } catch {
    return [];
  }
}

/** All entries in localStorage (ignores plan limits). */
export function getAllEntries(): JournalEntry[] {
  return loadAllEntries();
}

function bumpMemoryEligibleCache(): void {
  memoryEligibleVersion += 1;
  bumpPhraseScanCache();
  clearResurfacingCaches();
  void import("@/lib/resurfacing/evidence-engine").then((mod) => {
    mod.clearConcreteEvidenceCache();
  });
}

/** Entries with a completed reflection — used for memory pattern surfacing. */
export function getMemoryEligibleEntries(): JournalEntry[] {
  if (memoryEligibleCachedVersion === memoryEligibleVersion) {
    return memoryEligibleCache;
  }
  memoryEligibleCache = loadAllEntries().filter((entry) => entry.reflectionPending !== true);
  memoryEligibleCachedVersion = memoryEligibleVersion;
  return memoryEligibleCache;
}

export function getMemoryEligibleEntriesVersion(): number {
  return memoryEligibleVersion;
}

export function isReflectionPendingEntry(entry: JournalEntry): boolean {
  return entry.reflectionPending === true;
}

/** Entries visible for the current plan (Free: latest 7). */
export function getEntries(): JournalEntry[] {
  const all = loadAllEntries();
  if (isProUser() || all.length <= FREE_ENTRY_LIMIT) return all;
  return all.slice(0, FREE_ENTRY_LIMIT);
}

export function getStoredEntryCount(): number {
  return loadAllEntries().length;
}

export function getLockedEntryCount(): number {
  const total = getStoredEntryCount();
  if (isProUser()) return 0;
  return Math.max(0, total - FREE_ENTRY_LIMIT);
}

export function getEntry(id: string): JournalEntry | undefined {
  return loadAllEntries().find((entry) => entry.id === id);
}

function persistEntries(entries: JournalEntry[]): void {
  safeSetJson(STORAGE_KEY, entries);
}

export function saveEntry(entry: JournalEntry): void {
  if (!isBrowser()) return;

  ensureStorageReady();

  const entries = loadAllEntries().filter((existing) => existing.id !== entry.id);
  entries.unshift(entry);
  persistEntries(entries);
  bumpMemoryEligibleCache();
  recordReflectionDay(entry.createdAt);
  trackReflectionMilestones(entries.length);
  if (entries.length === 1) {
    void import("@/lib/retention/day-two-return").then((mod) => {
      mod.anchorFirstReflectionForDayTwo(entry.createdAt);
    });
  }
  void import("@/lib/retention/first-week-observation").then((mod) => {
    mod.trackReflectionAfterPromptIfPending();
  });
  void import("@/lib/restraint/silence-intelligence").then((mod) => {
    mod.recordReflectionDuringSilence();
  });
  bumpTimingFromEntry(entry);
  trackMoatNewReflection(entry.id, entry.createdAt);
  void import("@/lib/intentions/long-term-intentions").then((mod) => {
    mod.syncLongTermIntentions(getMemoryEligibleEntries());
  });
  void import("@/lib/sync/schedule").then((mod) => mod.scheduleEncryptedSync());
}

export function deleteEntry(id: string): void {
  if (!isBrowser()) return;

  const entries = loadAllEntries().filter((entry) => entry.id !== id);
  persistEntries(entries);
  bumpMemoryEligibleCache();
  removeBookmark(id);
  void import("@/lib/open-loops/open-loop-storage").then((mod) =>
    mod.removeOpenLoopsForEntry(id),
  );
  void deleteAudio(id);
  void deletePhoto(id);
  void deleteAtmosphereImage(id);
}

/** Remove all journal entries from localStorage (call clearAllAudio separately). */
export async function deleteAllEntries(): Promise<number> {
  if (!isBrowser()) return 0;

  const entries = loadAllEntries();
  const count = entries.length;
  persistEntries([]);
  bumpMemoryEligibleCache();
  clearHabitState();

  for (const entry of entries) {
    await deleteAudio(entry.id);
    await deletePhoto(entry.id);
    await deleteAtmosphereImage(entry.id);
  }

  return count;
}
