import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import {
  applyResurfacingRarity,
  candidateFromResurfacingNote,
  gapDaysBetweenEntries,
  RESURFACING_LONG_SILENCE_DAYS,
  RESURFACING_MIN_ABSENCE_DAYS,
  RESURFACING_MIN_WEIGHT,
  type ResurfacingSurface,
} from "@/lib/memory/resurfacing-priority";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type { ResurfacingKind, ResurfacingNote, ResurfacingReport } from "@/types/resurfacing";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";

const ABSENCE_DAYS = RESURFACING_MIN_ABSENCE_DAYS;
const LONG_SILENCE_DAYS = RESURFACING_LONG_SILENCE_DAYS;
const LOOP_RE =
  /\b(same loop|loop came back|came back briefly|keep coming back|again before|that loop)\b/i;
const HEDGE_RE =
  /\b(maybe|sort of|kind of|probably|not sure|something|stuff|indirectly|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|mum|dad|mother|father|clearly|for sure|definitely)\b/gi;

export interface ResurfacingOptions {
  entryId?: string;
  limit?: number;
  surface?: ResurfacingSurface;
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
  const fromTranscript = entry.transcript.trim();
  if (fromTranscript) return fromTranscript.slice(0, 160);
  return "";
}

function quoteAround(text: string, needle: string, radius = 70): string {
  const lower = text.toLowerCase();
  const idx = lower.indexOf(needle.toLowerCase());
  if (idx < 0) return text.slice(0, radius).trim();
  const start = Math.max(0, idx - 20);
  return text.slice(start, start + radius).trim();
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function evidencePair(past: JournalEntry, current: JournalEntry, currentQuote?: string) {
  return {
    pastQuote: snippet(past),
    currentQuote: currentQuote ?? snippet(current),
    pastDateLabel: formatRelativeDate(past.createdAt),
    currentDateLabel: formatRelativeDate(current.createdAt),
    pastEntryId: past.id,
    entryId: current.id,
  };
}

function hasEvidence(
  item: Pick<
    ResurfacingNote,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function pushCandidate(
  bucket: ResurfacingNote[],
  item: Omit<ResurfacingNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < RESURFACING_MIN_WEIGHT) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function detectTopicSilence(
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
    if (gap < LONG_SILENCE_DAYS) continue;

    const evidence = evidencePair(lastPrior, current);
    if (!hasEvidence(evidence)) continue;

    pushCandidate(notes, {
      id: `resurface-topic-${themeKey}-${current.id}`,
      kind: "topic_silence",
      text: "You came back to the same place.",
      strength: 64 + Math.min(gap, 14) + (priorMatches.length >= 2 ? 4 : 0),
      ...evidence,
    });
  }

  return notes;
}

function detectToneShift(
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
    if (gap < LONG_SILENCE_DAYS) continue;

    const priorAvg = roundAvg(priorMatches.map((e) => e.reflection.emotionalIntensity));
    const delta = priorAvg - current.reflection.emotionalIntensity;
    const evidence = evidencePair(lastPrior, current);
    if (!hasEvidence(evidence)) continue;

    if (delta >= 1.5) {
      pushCandidate(notes, {
        id: `resurface-calmer-${themeKey}-${current.id}`,
        kind: "calmer_return",
        text: "You came back with less tension.",
        strength: 64 + Math.round(delta * 4) + Math.min(gap, 8),
        ...evidence,
      });
    }

    if (current.reflection.emotionalIntensity - priorAvg >= 1.5) {
      pushCandidate(notes, {
        id: `resurface-heavier-${themeKey}-${current.id}`,
        kind: "heavier_return",
        text: "This carried more weight this time.",
        strength: 62 + Math.round((current.reflection.emotionalIntensity - priorAvg) * 4),
        ...evidence,
      });
    }

    const priorHedge = countMatches(lastPrior.transcript, HEDGE_RE);
    const nowHedge = countMatches(current.transcript, HEDGE_RE);
    const priorDirect = countMatches(lastPrior.transcript, DIRECT_RE);
    const nowDirect = countMatches(current.transcript, DIRECT_RE);

    if (priorHedge >= 1 && nowDirect > priorDirect && nowHedge <= priorHedge) {
      pushCandidate(notes, {
        id: `resurface-direct-${themeKey}-${current.id}`,
        kind: "direct_return",
        text: "You named this more directly.",
        strength: 63 + Math.min(gap, 8),
        ...evidence,
      });
    }
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
    if (gap < LONG_SILENCE_DAYS) continue;

    const priorEntry = allSorted.find((e) => e.id === lastPrior.entryId);
    if (!priorEntry) continue;

    const evidence = evidencePair(
      priorEntry,
      current,
      quoteAround(current.transcript, record.phrase),
    );
    if (!hasEvidence(evidence)) continue;

    pushCandidate(notes, {
      id: `resurface-phrase-${record.phrase}-${current.id}`,
      kind: "phrase_return",
      text: "You came back to the same place.",
      strength: 66 + Math.min(gap, 12) + Math.min(record.count, 4),
      ...evidence,
    });
  }

  return notes;
}

function detectPersonSilence(
  current: JournalEntry,
  allSorted: JournalEntry[],
): ResurfacingNote[] {
  const notes: ResurfacingNote[] = [];
  const snapshot = buildEntityMemoryFromEntries(allSorted);
  const people = snapshot.people;
  const currentDay = toDayKey(current.createdAt);
  const currentLower = current.transcript.toLowerCase();

  for (const person of people) {
    if (!person.entryIds.includes(current.id)) continue;
    if (person.mentionCount < 2) continue;
    if (!currentLower.includes(person.name.toLowerCase())) continue;

    const chronological = allSorted.filter((e) => person.entryIds.includes(e.id));
    const idx = chronological.findIndex((e) => e.id === current.id);
    if (idx <= 0) continue;

    const lastPrior = chronological[idx - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), currentDay);
    if (gap < ABSENCE_DAYS) continue;

    const evidence = evidencePair(
      lastPrior,
      current,
      quoteAround(current.transcript, person.name),
    );
    if (!hasEvidence(evidence)) continue;

    pushCandidate(notes, {
      id: `resurface-person-${person.id}-${current.id}`,
      kind: "person_silence",
      text:
        gap >= LONG_SILENCE_DAYS
          ? "You had not named this for a while."
          : "You had not named this for a while.",
      strength: 64 + Math.min(gap, 14) + Math.min(person.mentionCount, 4),
      ...evidence,
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
  const entities = [...snapshot.concerns, ...snapshot.topics];
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
    if (gap < LONG_SILENCE_DAYS) continue;

    const evidence = evidencePair(
      lastPrior,
      current,
      quoteAround(current.transcript, entity.name),
    );
    if (!hasEvidence(evidence)) continue;

    pushCandidate(notes, {
      id: `resurface-entity-${entity.id}-${current.id}`,
      kind: "topic_silence",
      text: "You came back to the same place.",
      strength: 64 + Math.min(gap, 12),
      ...evidence,
    });
  }

  return notes;
}

function detectLoopReturns(
  current: JournalEntry,
  prior: JournalEntry[],
): ResurfacingNote[] {
  if (!LOOP_RE.test(current.transcript) && !/\b(loop|same pattern|again before)\b/i.test(current.transcript)) {
    return [];
  }

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

    const evidence = evidencePair(lastPrior, current);
    if (!hasEvidence(evidence)) continue;

    pushCandidate(notes, {
      id: `resurface-loop-${themeKey}-${current.id}`,
      kind: "loop_return",
      text: "You came back to the same loop.",
      strength: 66 + Math.min(gap, 10),
      ...evidence,
    });
  }

  if (notes.length === 0) {
    const lastLoop = [...prior]
      .reverse()
      .find((e) => LOOP_RE.test(e.transcript) || /\b(loop|same pattern)\b/i.test(e.transcript));
    if (!lastLoop) return notes;

    const gap = daysBetweenKeys(toDayKey(lastLoop.createdAt), currentDay);
    if (gap < ABSENCE_DAYS) return notes;

    const evidence = evidencePair(lastLoop, current);
    if (!hasEvidence(evidence)) return notes;

    pushCandidate(notes, {
      id: `resurface-loop-generic-${current.id}`,
      kind: "loop_return",
      text: "You came back to the same loop.",
      strength: 64 + Math.min(gap, 10),
      ...evidence,
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
    ...detectLoopReturns(current, prior),
    ...detectToneShift(current, prior),
    ...detectPersonSilence(current, allSorted),
    ...detectTopicSilence(current, prior),
    ...detectPhraseReturns(current, allSorted),
    ...detectEntityReturns(current, allSorted),
  ];
}

const KIND_PRIORITY: ResurfacingKind[] = [
  "loop_return",
  "calmer_return",
  "heavier_return",
  "direct_return",
  "person_silence",
  "topic_silence",
  "phrase_return",
];

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
  const sorted = dedupeNotes(notes);
  const picked: ResurfacingNote[] = [];
  const usedKinds = new Set<ResurfacingKind>();

  for (const kind of KIND_PRIORITY) {
    if (picked.length >= limit) break;
    const match = sorted.find((n) => n.kind === kind && !usedKinds.has(kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
    }
  }

  for (const note of sorted) {
    if (picked.length >= limit) break;
    if (picked.some((p) => p.id === note.id)) continue;
    picked.push(note);
  }

  return picked.slice(0, limit);
}

function reportForEntry(
  sorted: JournalEntry[],
  entryId: string,
  limit: number,
  surface: ResurfacingSurface,
): ResurfacingReport {
  const idx = sorted.findIndex((e) => e.id === entryId);
  if (idx <= 0) return { notes: [], hasData: false };

  const raw = pickBest(detectForEntry(sorted[idx], sorted.slice(0, idx), sorted), limit * 4);
  const memoryNotes = applyResurfacingRarity(
    raw.map((note) => {
      const gap = gapDaysBetweenEntries(sorted, note.pastEntryId, note.entryId);
      return candidateFromResurfacingNote(
        note,
        resurfacingToMemoryNotes([note])[0],
        gap,
      );
    }),
    { surface, limit, record: true },
  );

  const notes = raw.filter((note) =>
    memoryNotes.some((memory) => memory.id === note.id),
  );

  return { notes, hasData: notes.length > 0 };
}

/** Detect quiet resurfacing — topics, people, phrases, and loops returning after silence. */
export function buildResurfacingReport(
  entries: JournalEntry[],
  options: ResurfacingOptions = {},
): ResurfacingReport {
  const limit = options.limit ?? 1;
  const surface = options.surface ?? "homepage";
  const sorted = sortedEntries(entries);

  if (sorted.length < 2) {
    return { notes: [], hasData: false };
  }

  if (options.entryId) {
    return reportForEntry(sorted, options.entryId, limit, surface);
  }

  const latest = sorted[sorted.length - 1];
  return reportForEntry(sorted, latest.id, limit, surface);
}

export function resurfacingToMemoryNotes(notes: ResurfacingNote[]): MemoryNote[] {
  return notes.map((note) => ({
    id: note.id,
    text: note.text,
    category: "returned" as const,
    confidence: note.strength,
    pastQuote: note.pastQuote,
    currentQuote: note.currentQuote,
    pastDateLabel: note.pastDateLabel,
    currentDateLabel: note.currentDateLabel,
    pastEntryId: note.pastEntryId,
    entryId: note.entryId,
  }));
}

export function entryResurfacingNotes(
  entries: JournalEntry[],
  entryId: string,
  limit = 1,
): MemoryNote[] {
  return applyMemoryHierarchy(
    resurfacingToMemoryNotes(
      buildResurfacingReport(entries, { entryId, limit, surface: "entry" }).notes,
    ),
    entries,
    limit,
  );
}

export function latestResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
  surface: ResurfacingSurface = "homepage",
): MemoryNote[] {
  return applyMemoryHierarchy(
    resurfacingToMemoryNotes(buildResurfacingReport(entries, { limit, surface }).notes),
    entries,
    limit,
  );
}

export function homepageResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  return latestResurfacingNotes(entries, limit, "homepage");
}

export function archiveResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  return latestResurfacingNotes(entries, limit, "timeline");
}

export function memoryResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  return latestResurfacingNotes(entries, limit, "memory");
}

export function monthlyResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  return latestResurfacingNotes(entries, limit, "monthly");
}
