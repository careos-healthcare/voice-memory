import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  rankByEmotionalWeight,
  weightRevisitationKind,
} from "@/lib/memory/emotional-weight";
import {
  applyResurfacingRarity,
  candidateFromRevisitationNote,
  gapDaysBetweenEntries,
  RESURFACING_MIN_WEIGHT,
  type ResurfacingSurface,
} from "@/lib/memory/resurfacing-priority";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import type {
  RevisitationContext,
  RevisitationKind,
  RevisitationNote,
  RevisitationReport,
} from "@/types/revisitation";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import { filterDelayedPayoffGate } from "@/lib/memory/delayed-payoff";

const OLDER_GAP_DAYS = 12;
const LOOP_GAP_DAYS = 7;
const LOOP_RE =
  /\b(same loop|loop came back|came back briefly|keep coming back|again before|that loop)\b/i;

export interface RevisitationOptions {
  context: RevisitationContext;
  entryId?: string;
  limit?: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function snippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function hasTheme(entry: JournalEntry, themeKey: string): boolean {
  return entry.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey);
}

function pushCandidate(
  bucket: RevisitationNote[],
  item: Omit<RevisitationNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < RESURFACING_MIN_WEIGHT) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function detectRelatedOlder(
  anchor: JournalEntry,
  prior: JournalEntry[],
): RevisitationNote[] {
  const notes: RevisitationNote[] = [];
  const anchorDay = toDayKey(anchor.createdAt);

  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), anchorDay);
    if (gap < OLDER_GAP_DAYS) continue;

    const overlap = sharedThemes(anchor, old);
    if (overlap.length === 0) continue;

    pushCandidate(notes, {
      id: `revisit-related-${old.id}-${anchor.id}`,
      kind: "related_older",
      text: "You were carrying this differently then.",
      strength: 60 + Math.min(gap, 14) + overlap.length * 3,
      pastQuote: snippet(old),
      currentQuote: snippet(anchor),
      pastEntryId: old.id,
      entryId: anchor.id,
    });
    break;
  }

  return notes;
}

function detectFirstTopic(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): RevisitationNote[] {
  const notes: RevisitationNote[] = [];

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const hits = allSorted.filter((e) => hasTheme(e, themeKey));
    if (hits.length < 2) continue;

    const first = hits[0];
    if (first.id === anchor.id) continue;

    pushCandidate(notes, {
      id: `revisit-first-${themeKey}-${anchor.id}`,
      kind: "first_topic",
      text: "You had not spoken about this before.",
      strength: 64 + hits.length * 2,
      pastQuote: snippet(first),
      currentQuote: snippet(anchor),
      pastEntryId: first.id,
      entryId: anchor.id,
    });
    break;
  }

  return notes;
}

function detectBeforeQuieter(
  anchor: JournalEntry,
  prior: JournalEntry[],
): RevisitationNote[] {
  if (anchor.reflection.emotionalIntensity > 4.5) return [];

  const notes: RevisitationNote[] = [];

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const intense = [...prior]
      .reverse()
      .find((e) => hasTheme(e, themeKey) && e.reflection.emotionalIntensity >= 6);
    if (!intense) continue;
    if (anchor.reflection.emotionalIntensity > intense.reflection.emotionalIntensity - 1.5) {
      continue;
    }

    pushCandidate(notes, {
      id: `revisit-before-quiet-${intense.id}-${anchor.id}`,
      kind: "before_quieter",
      text: "This was before it got quieter.",
      strength: 63 + Math.round(intense.reflection.emotionalIntensity - anchor.reflection.emotionalIntensity) * 3,
      pastQuote: snippet(intense),
      currentQuote: snippet(anchor),
      pastEntryId: intense.id,
      entryId: anchor.id,
    });
    break;
  }

  return notes;
}

function detectReadsDifferently(
  anchor: JournalEntry,
  prior: JournalEntry[],
  latest: JournalEntry,
): RevisitationNote[] {
  const notes: RevisitationNote[] = [];

  if (anchor.id !== latest.id) {
    const overlap = sharedThemes(anchor, latest);
    const intensityDelta = Math.abs(
      anchor.reflection.emotionalIntensity - latest.reflection.emotionalIntensity,
    );
    const moodDiff = anchor.reflection.mood !== latest.reflection.mood;

    if (overlap.length > 0 && (intensityDelta >= 1.5 || moodDiff)) {
      pushCandidate(notes, {
        id: `revisit-diff-now-${anchor.id}`,
        kind: "reads_differently",
        text: "You were carrying this differently then.",
        strength: 62 + overlap.length * 3 + Math.round(intensityDelta * 2),
        pastQuote: snippet(anchor),
        currentQuote: snippet(latest),
        pastEntryId: anchor.id,
        entryId: latest.id,
      });
      return notes;
    }
  }

  const anchorDay = toDayKey(anchor.createdAt);
  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), anchorDay);
    if (gap < OLDER_GAP_DAYS) continue;

    const overlap = sharedThemes(anchor, old);
    const intensityDelta = Math.abs(
      anchor.reflection.emotionalIntensity - old.reflection.emotionalIntensity,
    );
    if (overlap.length === 0 || intensityDelta < 1.5) continue;

    pushCandidate(notes, {
      id: `revisit-diff-${old.id}-${anchor.id}`,
      kind: "reads_differently",
      text: "You were carrying this differently then.",
      strength: 60 + overlap.length * 3 + Math.round(intensityDelta * 2),
      pastQuote: snippet(old),
      currentQuote: snippet(anchor),
      pastEntryId: old.id,
      entryId: anchor.id,
    });
    break;
  }

  return notes;
}

function detectLoopReturn(
  anchor: JournalEntry,
  prior: JournalEntry[],
): RevisitationNote[] {
  if (!LOOP_RE.test(anchor.transcript)) return [];

  const notes: RevisitationNote[] = [];
  const anchorDay = toDayKey(anchor.createdAt);
  const lastLoop = [...prior].reverse().find((e) => LOOP_RE.test(e.transcript));
  if (!lastLoop) return notes;

  const gap = daysBetweenKeys(toDayKey(lastLoop.createdAt), anchorDay);
  if (gap < LOOP_GAP_DAYS) return notes;

  pushCandidate(notes, {
    id: `revisit-loop-${lastLoop.id}-${anchor.id}`,
    kind: "loop_return",
    text: "You were carrying this differently then.",
    strength: 61 + Math.min(gap, 10),
    pastQuote: snippet(lastLoop),
    currentQuote: snippet(anchor),
    pastEntryId: lastLoop.id,
    entryId: anchor.id,
  });

  return notes;
}

function detectWorthRevisit(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): RevisitationNote[] {
  const notes: RevisitationNote[] = [];
  const idx = allSorted.findIndex((e) => e.id === anchor.id);
  if (idx <= 0) return notes;

  for (let i = 0; i < idx; i += 1) {
    const candidate = allSorted[i];
    const after = allSorted.slice(i + 1, Math.min(i + 4, idx + 1));
    if (after.length < 2) continue;

    const themes = candidate.reflection.recurringThemes.map((t) => t.toLowerCase());
    if (themes.length === 0) continue;

    const afterOnTheme = after.filter((e) =>
      e.reflection.recurringThemes.some((t) => themes.includes(t.toLowerCase())),
    );
    if (afterOnTheme.length < 2) continue;

    const beforeIntensity = candidate.reflection.emotionalIntensity;
    const afterAvg = roundAvg(afterOnTheme.map((e) => e.reflection.emotionalIntensity));
    if (beforeIntensity - afterAvg < 1.5) continue;

    pushCandidate(notes, {
      id: `revisit-changed-${candidate.id}-${anchor.id}`,
      kind: "worth_revisit",
      text: "You were carrying this differently then.",
      strength: 59 + Math.round(beforeIntensity - afterAvg) * 3,
      pastQuote: snippet(candidate),
      currentQuote: snippet(anchor),
      pastEntryId: candidate.id,
      entryId: anchor.id,
    });
    break;
  }

  return notes;
}

function detectForAnchor(
  anchor: JournalEntry,
  prior: JournalEntry[],
  allSorted: JournalEntry[],
  latest: JournalEntry,
): RevisitationNote[] {
  return [
    ...detectBeforeQuieter(anchor, prior),
    ...detectFirstTopic(anchor, allSorted),
    ...detectReadsDifferently(anchor, prior, latest),
    ...detectRelatedOlder(anchor, prior),
    ...detectLoopReturn(anchor, prior),
    ...detectWorthRevisit(anchor, allSorted),
  ];
}

const CONTEXT_PRIORITY: Record<RevisitationContext, RevisitationKind[]> = {
  homepage: ["before_quieter", "first_topic", "related_older", "worth_revisit", "loop_return"],
  entry: ["reads_differently", "before_quieter", "first_topic", "related_older", "loop_return"],
  timeline: ["worth_revisit", "first_topic", "before_quieter", "related_older", "reads_differently"],
  monthly: ["before_quieter", "worth_revisit", "first_topic", "related_older"],
  memory: ["related_older", "first_topic", "worth_revisit", "before_quieter", "loop_return"],
};

function dedupeNotes(notes: RevisitationNote[]): RevisitationNote[] {
  const seen = new Set<string>();
  return notes
    .filter((n) => n.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((n) => {
      const key = `${n.pastEntryId ?? ""}:${n.text.slice(0, 40)}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickForContext(
  notes: RevisitationNote[],
  context: RevisitationContext,
  limit: number,
  sorted: JournalEntry[],
): RevisitationNote[] {
  const ranked = rankByEmotionalWeight(
    dedupeNotes(notes),
    (note) =>
      weightRevisitationKind(
        note.kind,
        note.strength,
        gapDaysBetweenEntries(sorted, note.pastEntryId, note.entryId),
      ),
    notes.length,
  );
  const priority = CONTEXT_PRIORITY[context];
  const picked: RevisitationNote[] = [];
  const usedKinds = new Set<RevisitationKind>();

  for (const kind of priority) {
    if (picked.length >= limit) break;
    const match = ranked.find((n) => n.kind === kind && !usedKinds.has(kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
    }
  }

  for (const note of ranked) {
    if (picked.length >= limit) break;
    if (picked.some((p) => p.id === note.id)) continue;
    picked.push(note);
  }

  return picked.slice(0, limit);
}

/** Detect quiet prompts to revisit older reflections. */
export function buildRevisitationReport(
  entries: JournalEntry[],
  options: RevisitationOptions,
): RevisitationReport {
  const limit = options.limit ?? 1;
  const sorted = sortedEntries(entries);

  if (sorted.length < 2) {
    return { notes: [], hasData: false };
  }

  const latest = sorted[sorted.length - 1];
  let anchor = latest;
  let prior = sorted.slice(0, -1);

  if (options.context === "entry" && options.entryId) {
    const idx = sorted.findIndex((e) => e.id === options.entryId);
    if (idx < 0) return { notes: [], hasData: false };
    anchor = sorted[idx];
    prior = sorted.slice(0, idx);
  }

  const candidates = detectForAnchor(anchor, prior, sorted, latest);
  const notes = pickForContext(candidates, options.context, limit * 4, sorted);
  return { notes, hasData: notes.length > 0 };
}

export function revisitationToNotes(notes: RevisitationNote[]): MemoryNote[] {
  return notes.map((note) => ({
    id: note.id,
    text: note.text,
    category: "returned" as const,
    confidence: note.strength,
    pastQuote: note.pastQuote,
    currentQuote: note.currentQuote,
    pastEntryId: note.pastEntryId,
    entryId: note.entryId,
  }));
}

function applyRevisitationRarity(
  entries: JournalEntry[],
  notes: RevisitationNote[],
  surface: ResurfacingSurface,
  limit = 1,
): MemoryNote[] {
  return filterDelayedPayoffGate(
    entries,
    applyResurfacingRarity(
      notes.map((note) =>
        candidateFromRevisitationNote(
          note,
          revisitationToNotes([note])[0],
          gapDaysBetweenEntries(entries, note.pastEntryId, note.entryId),
        ),
      ),
      { surface, limit, record: true, entries },
    ),
  );
}

export function homepageRevisitationNotes(entries: JournalEntry[]): MemoryNote[] {
  const report = buildRevisitationReport(entries, { context: "homepage", limit: 1 });
  return applyMemoryHierarchy(
    applyRevisitationRarity(entries, report.notes, "homepage", 1),
    entries,
    1,
  );
}

export function entryRevisitationNotes(
  entries: JournalEntry[],
  entryId: string,
): MemoryNote[] {
  const report = buildRevisitationReport(entries, { context: "entry", entryId, limit: 1 });
  return applyMemoryHierarchy(
    applyRevisitationRarity(entries, report.notes, "entry", 1),
    entries,
    1,
  );
}

export function timelineRevisitationNotes(entries: JournalEntry[]): MemoryNote[] {
  const report = buildRevisitationReport(entries, { context: "timeline", limit: 1 });
  return applyMemoryHierarchy(
    applyRevisitationRarity(entries, report.notes, "timeline", 1),
    entries,
    1,
  );
}

export function monthlyRevisitationNotes(entries: JournalEntry[]): MemoryNote[] {
  const report = buildRevisitationReport(entries, { context: "monthly", limit: 1 });
  return applyMemoryHierarchy(
    applyRevisitationRarity(entries, report.notes, "monthly", 1),
    entries,
    1,
  );
}

export function memoryRevisitationNotes(entries: JournalEntry[]): MemoryNote[] {
  const report = buildRevisitationReport(entries, { context: "memory", limit: 1 });
  return applyMemoryHierarchy(
    applyRevisitationRarity(entries, report.notes, "memory", 1),
    entries,
    1,
  );
}
