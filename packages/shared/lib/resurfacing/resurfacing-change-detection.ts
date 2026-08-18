import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { linkedEntriesForNote } from "@/lib/refinement/note-linked-entries";
import { quoteSimilarity } from "@/lib/refinement/then-vs-now-quotes";
import { assessConcreteResurfacingEvidence } from "@/lib/resurfacing/evidence-engine";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const MIN_MOOD_DELTA = 0.8;
const MIN_INTENSITY_DELTA = 1;
const MIN_TRANSCRIPT_SHIFT = 0.22;

function tokenSet(text: string): Set<string> {
  return new Set(
    text
      .toLowerCase()
      .replace(/[^\w\s]/g, " ")
      .split(/\s+/)
      .filter((w) => w.length > 3),
  );
}

function transcriptShift(a: string, b: string): number {
  const left = tokenSet(a);
  const right = tokenSet(b);
  if (left.size === 0 || right.size === 0) return 0;
  let overlap = 0;
  for (const token of left) {
    if (right.has(token)) overlap += 1;
  }
  return 1 - overlap / Math.max(left.size, right.size);
}

/** Resurface only when archive shows something actually shifted. */
export function scoreDetectableChange(
  note: MemoryNote,
  entries: JournalEntry[],
): number {
  const linked = linkedEntriesForNote(note, entries);
  if (linked.length < 2) {
    const evidence = assessConcreteResurfacingEvidence(note, entries);
    return evidence.backed ? Math.min(55, evidence.strength) : 0;
  }

  const sorted = [...linked].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const past = sorted[0];
  const current = sorted[sorted.length - 1];
  let score = 0;

  const moodDelta = Math.abs(
    (current.reflection?.emotionalIntensity ?? 0) -
      (past.reflection?.emotionalIntensity ?? 0),
  );
  if (moodDelta >= MIN_MOOD_DELTA) score += 22;

  const gap = daysBetweenKeys(
    toDayKey(past.createdAt),
    toDayKey(current.createdAt),
  );
  if (gap >= 3) score += 12;
  if (gap >= 7) score += 8;

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    const sim = quoteSimilarity(note.pastQuote, note.currentQuote);
    if (sim < 0.88 && sim > 0.35) score += 28;
    if (sim <= 0.35) score += 18;
  }

  const shift = transcriptShift(past.transcript ?? "", current.transcript ?? "");
  if (shift >= MIN_TRANSCRIPT_SHIFT) score += 20;

  if (/\b(quieter|heavier|direct|different|stopped|started|named)\b/i.test(note.text)) {
    score += 14;
  }

  const evidence = assessConcreteResurfacingEvidence(note, entries);
  if (evidence.kinds.includes("mood_shift")) score += 16;
  if (evidence.kinds.includes("repeated_phrase") && shift >= 0.15) score += 12;

  return Math.min(100, score);
}

export function hasDetectableChange(
  note: MemoryNote,
  entries: JournalEntry[],
  minScore = 36,
): boolean {
  return scoreDetectableChange(note, entries) >= minScore;
}

export function shouldSuppressWithoutDetectableChange(
  note: MemoryNote,
  entries: JournalEntry[],
): boolean {
  return !hasDetectableChange(note, entries);
}
