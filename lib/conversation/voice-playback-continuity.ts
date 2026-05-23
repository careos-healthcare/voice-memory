import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type VoicePlaybackPairKind = "then_vs_now" | "related" | "current_only";

export interface VoicePlaybackPair {
  kind: VoicePlaybackPairKind;
  thenEntry: JournalEntry | null;
  nowEntry: JournalEntry;
}

function entryById(entries: JournalEntry[], id?: string): JournalEntry | null {
  if (!id) return null;
  return entries.find((entry) => entry.id === id) ?? null;
}

function isThenVsNowNote(note: MemoryNote): boolean {
  return note.id.startsWith("tvn-") || Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());
}

function noteAnchorsCurrent(note: MemoryNote, currentEntryId: string): boolean {
  return !note.entryId || note.entryId === currentEntryId;
}

/** Resolve then/now or one related older clip for entry playback. */
export function resolveVoicePlaybackPair(
  currentEntry: JournalEntry,
  allEntries: JournalEntry[],
  options: {
    thenVsNow: MemoryNote[];
    relatedNotes: MemoryNote[];
  },
): VoicePlaybackPair {
  for (const note of options.thenVsNow) {
    if (!note.pastEntryId || !noteAnchorsCurrent(note, currentEntry.id)) continue;
    const thenEntry = entryById(allEntries, note.pastEntryId);
    if (thenEntry && thenEntry.id !== currentEntry.id) {
      return {
        kind: "then_vs_now",
        thenEntry,
        nowEntry: currentEntry,
      };
    }
  }

  const related = options.relatedNotes
    .filter(
      (note) =>
        note.pastEntryId &&
        noteAnchorsCurrent(note, currentEntry.id) &&
        !isThenVsNowNote(note),
    )
    .sort((a, b) => b.confidence - a.confidence);

  for (const note of related) {
    const thenEntry = entryById(allEntries, note.pastEntryId);
    if (thenEntry && thenEntry.id !== currentEntry.id) {
      return {
        kind: "related",
        thenEntry,
        nowEntry: currentEntry,
      };
    }
  }

  return {
    kind: "current_only",
    thenEntry: null,
    nowEntry: currentEntry,
  };
}

export const VOICE_PLAYBACK_LABELS: Record<
  VoicePlaybackPairKind,
  { then?: string; now: string }
> = {
  then_vs_now: {
    then: "Listen to how you sounded then",
    now: "Listen to how you sound now",
  },
  related: {
    then: "Listen to an earlier moment",
    now: "Listen to how you sound now",
  },
  current_only: {
    now: "Your voice",
  },
};
