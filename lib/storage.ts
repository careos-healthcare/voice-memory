import { deleteAudio } from "@/lib/audio-storage";
import { recordReflectionDay } from "@/lib/habit-storage";
import { normalizeReflection } from "@/lib/reflection";
import type { JournalEntry, Reflection } from "@/types/journal";

const STORAGE_KEY = "voicememory_entries";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getEntries(): JournalEntry[] {
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

export function getEntry(id: string): JournalEntry | undefined {
  return getEntries().find((entry) => entry.id === id);
}

export function saveEntry(entry: JournalEntry): void {
  if (!isBrowser()) return;

  const entries = getEntries().filter((existing) => existing.id !== entry.id);
  entries.unshift(entry);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(entries));
  recordReflectionDay(entry.createdAt);
}

export function deleteEntry(id: string): void {
  if (!isBrowser()) return;

  const entries = getEntries().filter((entry) => entry.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(entries));
  void deleteAudio(id);
}
