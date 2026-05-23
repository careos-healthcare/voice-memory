import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import type { ResurfacingKind, ResurfacingNote, ResurfacingReport } from "@/types/resurfacing";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const ABSENCE_DAYS = 7;
const LONG_ABSENCE_DAYS = 14;
const LOOP_RE =
  /\b(same loop|loop came back|came back briefly|keep coming back|again before|that loop)\b/i;

export interface ResurfacingOptions {
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

function quoteAround(text: string, needle: string, radius = 70): string {
  const lower = text.toLowerCase();
  const idx = lower.indexOf(needle.toLowerCase());
  if (idx < 0) return text.slice(0, radius);
  const start = Math.max(0, idx - 20);
  return text.slice(start, start + radius).trim();
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function isRecentEntry(entry: JournalEntry, withinDays = 2): boolean {
  const gap = daysBetweenKeys(toDayKey(entry.createdAt), toDayKey(new Date().toISOString()));
  return gap <= withinDays;
}

function copyForReturn(gapDays: number, current: JournalEntry): string {
  if (isRecentEntry(current) && gapDays >= ABSENCE_DAYS) return "This came back today.";
  if (gapDays >= LONG_ABSENCE_DAYS) return "This has not appeared for a while.";
  return `You last talked about this ${gapDays} days ago.`;
}

function pushCandidate(
  bucket: ResurfacingNote[],
  item: Omit<ResurfacingNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function detectTopicReturns(
  current: JournalEntry,
  prior: JournalEntry[],
): ResurfacingNote[] {
  const notes: ResurfacingNote[] = [];
  const currentDay = toDayKey(current.createdAt);

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorMatches = prior.filter((e) =>
      e.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey),
    );
    if (priorMatches.length === 0) continue;

    const lastPrior = priorMatches[priorMatches.length - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), currentDay);
    if (gap < ABSENCE_DAYS) continue;

    const priorAvg = roundAvg(priorMatches.map((e) => e.reflection.emotionalIntensity));
    const delta = priorAvg - current.reflection.emotionalIntensity;
    const pastQuote = snippet(lastPrior);
    const currentQuote = snippet(current);

    if (delta >= 1.5) {
      pushCandidate(notes, {
        id: `resurface-quieter-${themeKey}-${current.id}`,
        kind: "quieter_return",
        text: "This sounds quieter than last time.",
        strength: 62 + Math.round(delta * 4) + Math.min(gap, 10),
        pastQuote,
        currentQuote,
        pastEntryId: lastPrior.id,
        entryId: current.id,
      });
      continue;
    }

    if (current.reflection.emotionalIntensity - priorAvg >= 1.5) {
      pushCandidate(notes, {
        id: `resurface-heavier-${themeKey}-${current.id}`,
        kind: "heavier_return",
        text: copyForReturn(gap, current),
        strength: 60 + Math.round((current.reflection.emotionalIntensity - priorAvg) * 4),
        pastQuote,
        currentQuote,
        pastEntryId: lastPrior.id,
        entryId: current.id,
      });
      continue;
    }

    const kind: ResurfacingKind =
      gap >= ABSENCE_DAYS && gap < LONG_ABSENCE_DAYS ? "last_appeared" : "topic_return";

    pushCandidate(notes, {
      id: `resurface-topic-${themeKey}-${current.id}`,
      kind,
      text: copyForReturn(gap, current),
      strength: 58 + Math.min(gap, 12) + (priorMatches.length >= 2 ? 4 : 0),
      pastQuote,
      currentQuote,
      pastEntryId: lastPrior.id,
      entryId: current.id,
    });
  }

  return notes;
}

function detectPhraseReturns(
  current: JournalEntry,
  allSorted: JournalEntry[],
): ResurfacingNote[] {
  const notes: ResurfacingNote[] = [];
  const phrases = buildPhraseMemory(allSorted);
  const currentDay = toDayKey(current.createdAt);
  const currentLower = current.transcript.toLowerCase();

  for (const record of phrases) {
    if (record.count < 2 || record.entryIds.length < 2) continue;
    if (!record.entryIds.includes(current.id)) continue;
    if (!currentLower.includes(record.phrase.toLowerCase())) continue;

    const priorOccurrences = record.occurrences.filter((o) => o.entryId !== current.id);
    if (priorOccurrences.length === 0) continue;

    const lastPrior = priorOccurrences[priorOccurrences.length - 1];
    const gap = daysBetweenKeys(lastPrior.dateKey, currentDay);
    if (gap < ABSENCE_DAYS) continue;

    const priorEntry = allSorted.find((e) => e.id === lastPrior.entryId);
    const pastQuote = (priorEntry ? snippet(priorEntry) : lastPrior.snippet).slice(0, 160);
    const currentQuote = quoteAround(current.transcript, record.phrase);

    pushCandidate(notes, {
      id: `resurface-phrase-${record.phrase}-${current.id}`,
      kind: "phrase_return",
      text: copyForReturn(gap, current),
      strength: 59 + Math.min(gap, 10) + Math.min(record.count, 4),
      pastQuote,
      currentQuote,
      pastEntryId: lastPrior.entryId,
      entryId: current.id,
    });
  }

  return notes;
}

function detectEntityReturns(
  current: JournalEntry,
  allSorted: JournalEntry[],
): ResurfacingNote[] {
  const notes: ResurfacingNote[] = [];
  const snapshot = buildEntityMemoryFromEntries(allSorted);
  const entities = [...snapshot.people, ...snapshot.concerns, ...snapshot.topics];
  const currentDay = toDayKey(current.createdAt);
  const currentLower = current.transcript.toLowerCase();

  for (const entity of entities) {
    if (!entity.entryIds.includes(current.id)) continue;
    if (entity.mentionCount < 2) continue;
    if (!currentLower.includes(entity.name.toLowerCase())) continue;

    const chronological = allSorted.filter((e) => entity.entryIds.includes(e.id));
    const idx = chronological.findIndex((e) => e.id === current.id);
    if (idx <= 0) continue;

    const lastPrior = chronological[idx - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), currentDay);
    if (gap < ABSENCE_DAYS) continue;

    pushCandidate(notes, {
      id: `resurface-entity-${entity.id}-${current.id}`,
      kind: "entity_return",
      text: copyForReturn(gap, current),
      strength: 60 + Math.min(gap, 12) + Math.min(entity.mentionCount, 5),
      pastQuote: snippet(lastPrior),
      currentQuote: quoteAround(current.transcript, entity.name),
      pastEntryId: lastPrior.id,
      entryId: current.id,
    });
  }

  return notes;
}

function detectSimilarToToday(
  current: JournalEntry,
  prior: JournalEntry[],
): ResurfacingNote[] {
  const notes: ResurfacingNote[] = [];
  const currentDay = toDayKey(current.createdAt);
  let best: { entry: JournalEntry; score: number; gap: number } | null = null;

  for (const past of prior) {
    const overlap = sharedThemes(current, past);
    if (overlap.length < 2) continue;

    const gap = daysBetweenKeys(toDayKey(past.createdAt), currentDay);
    if (gap < ABSENCE_DAYS) continue;

    const moodMatch = past.reflection.mood === current.reflection.mood ? 4 : 0;
    const intensityClose =
      Math.abs(past.reflection.emotionalIntensity - current.reflection.emotionalIntensity) <= 1
        ? 3
        : 0;
    const score = overlap.length * 5 + moodMatch + intensityClose + Math.min(gap, 8);

    if (!best || score > best.score) {
      best = { entry: past, score, gap };
    }
  }

  if (!best || best.score < 16) return notes;

  pushCandidate(notes, {
    id: `resurface-similar-${current.id}-${best.entry.id}`,
    kind: "similar_to_today",
    text: copyForReturn(best.gap, current),
    strength: 60 + Math.min(best.score, 18),
    pastQuote: snippet(best.entry),
    currentQuote: snippet(current),
    pastEntryId: best.entry.id,
    entryId: current.id,
  });

  return notes;
}

function detectUnresolvedLoops(
  current: JournalEntry,
  prior: JournalEntry[],
): ResurfacingNote[] {
  if (!LOOP_RE.test(current.transcript)) return [];

  const notes: ResurfacingNote[] = [];
  const currentDay = toDayKey(current.createdAt);
  const sharedThemeKeys = current.reflection.recurringThemes.map((t) => t.toLowerCase());

  for (const themeKey of sharedThemeKeys) {
    const priorMatches = prior.filter(
      (e) =>
        e.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey) &&
        (LOOP_RE.test(e.transcript) || /\b(standup|same|again|loop)\b/i.test(e.transcript)),
    );
    if (priorMatches.length === 0) continue;

    const lastPrior = priorMatches[priorMatches.length - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), currentDay);
    if (gap < ABSENCE_DAYS) continue;

    pushCandidate(notes, {
      id: `resurface-loop-${themeKey}-${current.id}`,
      kind: "unresolved_loop",
      text: copyForReturn(gap, current),
      strength: 63 + Math.min(gap, 8),
      pastQuote: snippet(lastPrior),
      currentQuote: snippet(current),
      pastEntryId: lastPrior.id,
      entryId: current.id,
    });
  }

  if (notes.length === 0 && prior.some((e) => LOOP_RE.test(e.transcript))) {
    const lastLoop = [...prior].reverse().find((e) => LOOP_RE.test(e.transcript));
    if (!lastLoop) return notes;
    const gap = daysBetweenKeys(toDayKey(lastLoop.createdAt), currentDay);
    if (gap < ABSENCE_DAYS) return notes;

    pushCandidate(notes, {
      id: `resurface-loop-generic-${current.id}`,
      kind: "unresolved_loop",
      text: copyForReturn(gap, current),
      strength: 61 + Math.min(gap, 8),
      pastQuote: snippet(lastLoop),
      currentQuote: snippet(current),
      pastEntryId: lastLoop.id,
      entryId: current.id,
    });
  }

  return notes;
}

function detectForEntry(
  current: JournalEntry,
  prior: JournalEntry[],
  allSorted: JournalEntry[],
): ResurfacingNote[] {
  return [
    ...detectTopicReturns(current, prior),
    ...detectPhraseReturns(current, allSorted),
    ...detectEntityReturns(current, allSorted),
    ...detectSimilarToToday(current, prior),
    ...detectUnresolvedLoops(current, prior),
  ];
}

function dedupeNotes(notes: ResurfacingNote[]): ResurfacingNote[] {
  const seen = new Set<string>();
  return notes
    .filter((n) => n.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((n) => {
      const key = `${n.kind}:${n.pastEntryId ?? ""}:${n.entryId}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickBest(notes: ResurfacingNote[], limit: number): ResurfacingNote[] {
  return dedupeNotes(notes).slice(0, limit);
}

function reportForEntry(
  sorted: JournalEntry[],
  entryId: string,
  limit: number,
): ResurfacingReport {
  const idx = sorted.findIndex((e) => e.id === entryId);
  if (idx <= 0) return { notes: [], hasData: false };

  const notes = pickBest(
    detectForEntry(sorted[idx], sorted.slice(0, idx), sorted),
    limit,
  );
  return { notes, hasData: notes.length > 0 };
}

/** Detect quiet resurfacing — topics, phrases, people, and echoes of today. */
export function buildResurfacingReport(
  entries: JournalEntry[],
  options: ResurfacingOptions = {},
): ResurfacingReport {
  const limit = options.limit ?? 1;
  const sorted = sortedEntries(entries);

  if (sorted.length < 2) {
    return { notes: [], hasData: false };
  }

  if (options.entryId) {
    return reportForEntry(sorted, options.entryId, limit);
  }

  const latest = sorted[sorted.length - 1];
  return reportForEntry(sorted, latest.id, limit);
}

export function resurfacingToMemoryNotes(notes: ResurfacingNote[]): MemoryNote[] {
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

export function entryResurfacingNotes(
  entries: JournalEntry[],
  entryId: string,
): MemoryNote[] {
  return resurfacingToMemoryNotes(
    buildResurfacingReport(entries, { entryId, limit: 1 }).notes,
  );
}

/** One resurfacing note anchored to the latest reflection (homepage, memory, timeline). */
export function latestResurfacingNotes(entries: JournalEntry[]): MemoryNote[] {
  return resurfacingToMemoryNotes(buildResurfacingReport(entries, { limit: 1 }).notes);
}

export function homepageResurfacingNotes(entries: JournalEntry[]): MemoryNote[] {
  return latestResurfacingNotes(entries);
}

export function archiveResurfacingNotes(entries: JournalEntry[]): MemoryNote[] {
  return latestResurfacingNotes(entries);
}
