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

function bothHaveAudio(thenEntry: JournalEntry | null, nowEntry: JournalEntry): boolean {
  return Boolean(thenEntry?.audioId && nowEntry.audioId);
}

/** Resolve before/after audio for a revisit — both clips required. */
export function resolveRevisitVoicePlaybackPair(
  currentEntry: JournalEntry,
  allEntries: JournalEntry[],
  options: {
    contrast?: MemoryNote | null;
    reward?: MemoryNote | null;
  },
): VoicePlaybackPair | null {
  const notes = [options.contrast, options.reward].filter(Boolean) as MemoryNote[];

  for (const note of notes) {
    if (!note.pastEntryId) continue;
    const thenEntry = entryById(allEntries, note.pastEntryId);
    if (!thenEntry || thenEntry.id === currentEntry.id) continue;
    if (!bothHaveAudio(thenEntry, currentEntry)) continue;
    return {
      kind: "then_vs_now",
      thenEntry,
      nowEntry: currentEntry,
    };
  }

  return null;
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
    if (thenEntry && thenEntry.id !== currentEntry.id && bothHaveAudio(thenEntry, currentEntry)) {
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
    if (thenEntry && thenEntry.id !== currentEntry.id && bothHaveAudio(thenEntry, currentEntry)) {
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
    then: "Before",
    now: "Now",
  },
  related: {
    then: "Before",
    now: "Now",
  },
  current_only: {
    now: "Now",
  },
};

export function hasRevisitAudioComparison(pair: VoicePlaybackPair | null): boolean {
  return Boolean(pair?.thenEntry?.audioId && pair.nowEntry.audioId);
}
