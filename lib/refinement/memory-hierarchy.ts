import { weightMemoryNote } from "@/lib/memory/emotional-weight";
import { isTopicRecurrenceCopy } from "@/lib/refinement/knows-me-moments";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import type { EmotionalMilestone } from "@/types/emotional-milestone";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { MemoryReminder } from "@/types/memory-reminder";
import type { RelationshipContinuityNote } from "@/types/relationship-continuity";

export const MEMORY_HIERARCHY_MIN = 60;

export type MemoryHierarchySignal =
  | "turning_point"
  | "emotional_shift"
  | "identity_change"
  | "calmer_return"
  | "unfinished_loop"
  | "direct_naming"
  | "phrase_disappearance"
  | "reads_differently"
  | "routine_recurrence"
  | "weak_resurfacing"
  | "informational"
  | "generic_return";

export interface MemoryHierarchyScore {
  total: number;
  preferred: MemoryHierarchySignal[];
  suppressed: MemoryHierarchySignal[];
}

const PREFERRED_ID: Array<{ re: RegExp; signal: MemoryHierarchySignal; boost: number }> = [
  { re: /^knows-me-earlier|^knows-me-still-circling/, signal: "reads_differently", boost: 22 },
  { re: /^knows-me-apology|^knows-me-wording/, signal: "reads_differently", boost: 20 },
  { re: /^knows-me-named|^knows-me-direct|^knows-me-certainty/, signal: "direct_naming", boost: 22 },
  { re: /^knows-me-phrase-gone|^knows-me-circling/, signal: "phrase_disappearance", boost: 21 },
  { re: /^knows-me-weight|^knows-me-contrast|^knows-me-quieter/, signal: "emotional_shift", boost: 20 },
  { re: /^milestone-/, signal: "turning_point", boost: 24 },
  { re: /^tvn-/, signal: "reads_differently", boost: 22 },
  { re: /^revisit-diff|^revisit-related/, signal: "reads_differently", boost: 20 },
  { re: /^change-direct|^change-hedge|^continuity-first-direct/, signal: "direct_naming", boost: 22 },
  { re: /^change-phrase-gone|^moment-phrase|^change-absent/, signal: "phrase_disappearance", boost: 21 },
  { re: /^resurface-calmer|^recovery-|^revisit-before-quiet|^fam-resurface-first-calm/, signal: "calmer_return", boost: 20 },
  { re: /^resurface-loop|^revisit-loop|^recovery-spiral/, signal: "unfinished_loop", boost: 18 },
  { re: /^fam-resurface-different|^change-charged|^fam-resurface-opposite/, signal: "emotional_shift", boost: 17 },
  { re: /^relationship-.*different|^relationship-.*shifted/, signal: "identity_change", boost: 16 },
  { re: /^change-future|^change-charged/, signal: "turning_point", boost: 14 },
];

const SUPPRESSED_ID: Array<{ re: RegExp; signal: MemoryHierarchySignal; penalty: number }> = [
  { re: /^resurface-topic-|^resurface-entity-|^resurface-phrase-/, signal: "generic_return", penalty: 22 },
  { re: /^fam-resurface-similar/, signal: "routine_recurrence", penalty: 20 },
  { re: /^archive-|^continuity-depth-/, signal: "informational", penalty: 28 },
  { re: /^continuity-thread-|^continuity-recurring-/, signal: "routine_recurrence", penalty: 22 },
  { re: /^rhythm-|^time-/, signal: "routine_recurrence", penalty: 20 },
  { re: /^resurface-person-/, signal: "weak_resurfacing", penalty: 10 },
  { re: /^familiarity-/, signal: "routine_recurrence", penalty: 14 },
];

const GENERIC_TEXT: Array<{ re: RegExp; signal: MemoryHierarchySignal; penalty: number }> = [
  { re: /\bappeared again\b/i, signal: "generic_return", penalty: 24 },
  { re: /\bmoney returned\b/i, signal: "generic_return", penalty: 24 },
  { re: /\bwork appeared\b/i, signal: "generic_return", penalty: 22 },
  { re: /\btopic appeared\b/i, signal: "generic_return", penalty: 24 },
  { re: /\bsimilar theme\b/i, signal: "routine_recurrence", penalty: 22 },
  { re: /\byou came back to the same place\b/i, signal: "generic_return", penalty: 20 },
  { re: /\byou came back to the same loop\b/i, signal: "generic_return", penalty: 20 },
  { re: /\byou spoke about this the same way\b/i, signal: "routine_recurrence", penalty: 16 },
  { re: /\bolder reflections connecting\b/i, signal: "informational", penalty: 24 },
  { re: /\bstarting to mean something\b/i, signal: "informational", penalty: 24 },
  { re: /\bkept coming back to a few things\b/i, signal: "informational", penalty: 20 },
  { re: /\btends to return\b/i, signal: "routine_recurrence", penalty: 18 },
  { re: /\bweekly rhythm\b/i, signal: "routine_recurrence", penalty: 18 },
  { re: /\bgap between these entries\b/i, signal: "informational", penalty: 14 },
  { re: /\bsounds like the next part\b/i, signal: "informational", penalty: 12 },
];

const PREFERRED_TEXT: Array<{ re: RegExp; signal: MemoryHierarchySignal; boost: number }> = [
  { re: /\bthis used to feel heavier\b/i, signal: "emotional_shift", boost: 18 },
  { re: /\bstill circling this here\b/i, signal: "unfinished_loop", boost: 18 },
  { re: /\bstopped apologising\b/i, signal: "reads_differently", boost: 20 },
  { re: /\bsound more direct now\b/i, signal: "direct_naming", boost: 18 },
  { re: /\breads like an earlier version\b/i, signal: "reads_differently", boost: 18 },
  { re: /\bread(s)? differently\b/i, signal: "reads_differently", boost: 14 },
  { re: /\bbefore it got quieter\b/i, signal: "calmer_return", boost: 12 },
  { re: /\bnamed this more directly\b/i, signal: "direct_naming", boost: 14 },
  { re: /\bhad not (named|mentioned|finished)\b/i, signal: "unfinished_loop", boost: 12 },
  { re: /\bmore pressure before\b/i, signal: "emotional_shift", boost: 10 },
  { re: /\bsame loop\b/i, signal: "unfinished_loop", boost: 10 },
];

function linkedEntries(note: MemoryNote, entries: JournalEntry[]): JournalEntry[] {
  const ids = [note.pastEntryId, note.entryId].filter(Boolean) as string[];
  return entries.filter((entry) => ids.includes(entry.id));
}

function emotionalMeaningKey(note: MemoryNote): string {
  const idStem = note.id.replace(/-[a-f0-9-]{8,}$/i, "").slice(0, 32);
  const textStem = note.text.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 36);
  return `${note.category}:${idStem}:${textStem}`;
}

function scoreNote(note: MemoryNote, entries: JournalEntry[]): MemoryHierarchyScore {
  const text = note.text.trim();
  let total = Math.round(weightMemoryNote(note, entries) * 0.42 + note.confidence * 0.38);
  const preferred: MemoryHierarchySignal[] = [];
  const suppressed: MemoryHierarchySignal[] = [];

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    total += 16;
    preferred.push("reads_differently");
  }

  for (const row of PREFERRED_ID) {
    if (row.re.test(note.id)) {
      total += row.boost;
      preferred.push(row.signal);
    }
  }

  for (const row of PREFERRED_TEXT) {
    if (row.re.test(text)) {
      total += row.boost;
      preferred.push(row.signal);
    }
  }

  for (const row of SUPPRESSED_ID) {
    if (row.re.test(note.id)) {
      total -= row.penalty;
      suppressed.push(row.signal);
    }
  }

  for (const row of GENERIC_TEXT) {
    if (row.re.test(text)) {
      total -= row.penalty;
      suppressed.push(row.signal);
    }
  }

  const linked = linkedEntries(note, entries);
  if (linked.length > 0) {
    const avgIntensity =
      linked.reduce((sum, entry) => sum + entry.reflection.emotionalIntensity, 0) /
      linked.length;
    if (avgIntensity < 4) {
      total -= 14;
      suppressed.push("weak_resurfacing");
    } else if (avgIntensity >= 6.5) {
      total += 6;
    }

    if (linked.length >= 2) {
      const intensities = linked.map((entry) => entry.reflection.emotionalIntensity);
      const intensityDelta = Math.max(...intensities) - Math.min(...intensities);
      if (intensityDelta >= 1.5) {
        total += 12;
        preferred.push("emotional_shift");
      }

      const sortedLinked = [...linked].sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
      );
      const gap = daysBetweenKeys(
        toDayKey(sortedLinked[0].createdAt),
        toDayKey(sortedLinked[sortedLinked.length - 1].createdAt),
      );
      if (gap >= 14) {
        total += Math.min(Math.round(gap / 7), 10);
      }
    }

    if (linked.some((entry) => entry.audioId)) {
      total += 8;
    }
  }

  if (isTopicRecurrenceCopy(text)) {
    total -= 26;
    suppressed.push("generic_return");
  }

  if (note.id.startsWith("resurface-topic-") || note.id.startsWith("fam-resurface-similar")) {
    total -= 12;
    suppressed.push("weak_resurfacing");
  }

  if (note.confidence < 62) {
    total -= 10;
    suppressed.push("weak_resurfacing");
  }

  return {
    total: Math.max(0, Math.round(total)),
    preferred: [...new Set(preferred)],
    suppressed: [...new Set(suppressed)],
  };
}

/** Rank a memory note for user-facing hierarchy — internal only. */
export function scoreMemoryHierarchy(
  note: MemoryNote,
  entries: JournalEntry[],
): MemoryHierarchyScore {
  return scoreNote(note, entries);
}

/** Fewer, stronger memories — dedupe emotional meaning and drop weak notes. */
export function applyMemoryHierarchy(
  notes: MemoryNote[],
  entries: JournalEntry[],
  limit?: number,
  minScore = MEMORY_HIERARCHY_MIN,
): MemoryNote[] {
  const ranked = notes
    .map((note) => ({ note, score: scoreNote(note, entries) }))
    .filter((row) => row.score.total >= minScore)
    .sort(
      (a, b) =>
        b.score.total - a.score.total ||
        b.note.confidence - a.note.confidence,
    );

  const seen = new Set<string>();
  const picked: MemoryNote[] = [];

  for (const row of ranked) {
    const key = emotionalMeaningKey(row.note);
    if (seen.has(key)) continue;
    seen.add(key);
    picked.push(row.note);
    if (limit !== undefined && picked.length >= limit) break;
  }

  return picked;
}

export function noteFromRelationship(
  note: RelationshipContinuityNote,
): MemoryNote {
  return {
    id: note.id,
    text: note.text,
    category: "changed",
    confidence: note.strength,
    entryId: note.entryId,
    pastEntryId: note.pastEntryId,
  };
}

export function noteFromMilestone(milestone: EmotionalMilestone): MemoryNote {
  return {
    id: milestone.id,
    text: milestone.text,
    category: "changed",
    confidence: milestone.strength,
    entryId: milestone.entryId,
    pastEntryId: milestone.pastEntryId,
  };
}

export function noteFromReminder(reminder: MemoryReminder): MemoryNote {
  return {
    id: reminder.id,
    text: reminder.text,
    category: "returned",
    confidence: reminder.strength,
    entryId: reminder.entryId,
    pastEntryId: reminder.pastEntryId,
    pastQuote: reminder.pastQuote,
    currentQuote: reminder.currentQuote,
  };
}

export function applyRelationshipHierarchy(
  notes: RelationshipContinuityNote[],
  entries: JournalEntry[],
  limit?: number,
): RelationshipContinuityNote[] {
  const ranked = notes
    .map((note) => ({
      note,
      score: scoreNote(noteFromRelationship(note), entries),
    }))
    .filter((row) => row.score.total >= MEMORY_HIERARCHY_MIN)
    .sort((a, b) => b.score.total - a.score.total);

  const seen = new Set<string>();
  const picked: RelationshipContinuityNote[] = [];
  for (const row of ranked) {
    const key = emotionalMeaningKey(noteFromRelationship(row.note));
    if (seen.has(key)) continue;
    seen.add(key);
    picked.push(row.note);
    if (limit !== undefined && picked.length >= limit) break;
  }
  return picked;
}

export function applyMilestoneHierarchy(
  milestones: EmotionalMilestone[],
  entries: JournalEntry[],
  limit?: number,
): EmotionalMilestone[] {
  const ranked = milestones
    .map((milestone) => ({
      milestone,
      score: scoreNote(noteFromMilestone(milestone), entries),
    }))
    .filter((row) => row.score.total >= MEMORY_HIERARCHY_MIN - 4)
    .sort((a, b) => b.score.total - a.score.total);

  const seen = new Set<string>();
  const picked: EmotionalMilestone[] = [];
  for (const row of ranked) {
    const key = emotionalMeaningKey(noteFromMilestone(row.milestone));
    if (seen.has(key)) continue;
    seen.add(key);
    picked.push(row.milestone);
    if (limit !== undefined && picked.length >= limit) break;
  }
  return picked;
}

export function applyReminderHierarchy(
  reminder: MemoryReminder | null,
  entries: JournalEntry[],
): MemoryReminder | null {
  if (!reminder) return null;
  const passed = applyMemoryHierarchy([noteFromReminder(reminder)], entries, 1, MEMORY_HIERARCHY_MIN - 2);
  return passed.length > 0 ? reminder : null;
}

/** Pick the single strongest note from a pool. */
export function pickStrongestMemoryNote(
  notes: MemoryNote[],
  entries: JournalEntry[],
  minScore = MEMORY_HIERARCHY_MIN,
): MemoryNote | null {
  return applyMemoryHierarchy(notes, entries, 1, minScore)[0] ?? null;
}
