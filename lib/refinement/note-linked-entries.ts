import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export function linkedEntriesForNote(
  note: MemoryNote,
  entries: JournalEntry[],
): JournalEntry[] {
  const ids = [note.pastEntryId, note.entryId].filter(Boolean) as string[];
  return entries.filter((entry) => ids.includes(entry.id));
}
