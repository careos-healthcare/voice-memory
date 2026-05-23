import { deleteAudio } from "@/lib/audio-storage";
import { clearHabitState } from "@/lib/habit-storage";
import { recordReflectionDay } from "@/lib/habit-storage";
import { trackReflectionMilestones } from "@/lib/local-analytics";
import { normalizeReflection } from "@/lib/reflection";
import { FREE_ENTRY_LIMIT, isProUser } from "@/lib/subscription";
import type { JournalEntry, Reflection } from "@/types/journal";

const STORAGE_KEY = "voicememory_entries";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function loadAllEntries(): JournalEntry[] {
  if (!isBrowser()) return [];

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

export function saveEntry(entry: JournalEntry): void {
  if (!isBrowser()) return;

  const entries = loadAllEntries().filter((existing) => existing.id !== entry.id);
  entries.unshift(entry);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(entries));
  recordReflectionDay(entry.createdAt);
  trackReflectionMilestones(entries.length);
}

export function deleteEntry(id: string): void {
  if (!isBrowser()) return;

  const entries = loadAllEntries().filter((entry) => entry.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(entries));
  void deleteAudio(id);
}

/** Remove all journal entries from localStorage (call clearAllAudio separately). */
export async function deleteAllEntries(): Promise<number> {
  if (!isBrowser()) return 0;

  const entries = loadAllEntries();
  const count = entries.length;
  localStorage.setItem(STORAGE_KEY, JSON.stringify([]));
  clearHabitState();

  for (const entry of entries) {
    await deleteAudio(entry.id);
  }

  return count;
}
