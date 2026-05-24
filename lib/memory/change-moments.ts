import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import { detectRecoveryCandidates } from "@/lib/memory/recovery-memory";
import {
  applyResurfacingRarity,
  candidateFromChangeMomentNote,
  gapDaysBetweenEntries,
  type ResurfacingSurface,
} from "@/lib/memory/resurfacing-priority";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import {
  getThemeIntensityTrend,
  hasTheme,
  languageShiftOnTheme,
} from "@/lib/patterns/emotional-evolution";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type {
  ChangeMomentKind,
  ChangeMomentNote,
  ChangeMomentsContext,
  ChangeMomentsReport,
} from "@/types/change-moments";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";

const STRONG_MIN = 62;
const ABSENCE_DAYS = 14;
const FUTURE_RE =
  /\b(hope|hopeful|plan|planning|looking forward|next week|tomorrow|ship|will)\b/gi;

export interface ChangeMomentsOptions {
  context: ChangeMomentsContext;
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

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function evidence(past: JournalEntry, current: JournalEntry) {
  return {
    pastQuote: snippet(past),
    currentQuote: snippet(current),
    pastDateLabel: formatRelativeDate(past.createdAt),
    currentDateLabel: formatRelativeDate(current.createdAt),
    pastEntryId: past.id,
    entryId: current.id,
  };
}

function hasEvidence(
  item: Pick<ChangeMomentNote, "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel">,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function pushCandidate(
  bucket: ChangeMomentNote[],
  item: Omit<ChangeMomentNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < STRONG_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function detectLanguageShifts(
  current: JournalEntry,
  prior: JournalEntry[],
): ChangeMomentNote[] {
  const notes: ChangeMomentNote[] = [];

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorMatches = prior.filter((e) => hasTheme(e, themeKey));
    if (priorMatches.length === 0) continue;

    const lastPrior = priorMatches[priorMatches.length - 1];
    const shift = languageShiftOnTheme(lastPrior, current);
    const ev = evidence(lastPrior, current);

    if (shift.hedgeDelta >= 1 && shift.directDelta >= 0) {
      pushCandidate(notes, {
        id: `change-hedge-${themeKey}-${current.id}`,
        kind: "less_hedging",
        text: "You named this more directly.",
        strength: 64 + shift.hedgeDelta * 3,
        ...ev,
      });
    }

    if (shift.directDelta >= 1 && shift.hedgeDelta <= 0) {
      pushCandidate(notes, {
        id: `change-direct-${themeKey}-${current.id}`,
        kind: "more_direct",
        text: "You named this more directly.",
        strength: 63 + shift.directDelta * 3,
        ...ev,
      });
    }

    const trend = getThemeIntensityTrend([...priorMatches, current], themeKey);
    if (trend && trend.mentions >= 3 && trend.delta >= 1.5) {
      pushCandidate(notes, {
        id: `change-charged-${themeKey}-${current.id}`,
        kind: "less_charged",
        text: "There was more pressure before.",
        strength: 65 + Math.round(trend.delta * 3),
        pastQuote: snippet(trend.peakEntry),
        currentQuote: snippet(current),
        pastDateLabel: formatRelativeDate(trend.peakEntry.createdAt),
        currentDateLabel: formatRelativeDate(current.createdAt),
        pastEntryId: trend.peakEntry.id,
        entryId: current.id,
      });
    }

    const priorFuture = countMatches(lastPrior.transcript, FUTURE_RE);
    const nowFuture = countMatches(current.transcript, FUTURE_RE);
    if (priorFuture === 0 && nowFuture >= 2) {
      pushCandidate(notes, {
        id: `change-future-${themeKey}-${current.id}`,
        kind: "future_forward",
        text: "This reads differently here.",
        strength: 62 + nowFuture * 2,
        ...ev,
      });
    }
  }

  return notes;
}

function detectAbsentConcerns(allSorted: JournalEntry[]): ChangeMomentNote[] {
  const notes: ChangeMomentNote[] = [];
  const today = toDayKey(new Date().toISOString());
  const cutoff = addDaysToKey(today, -ABSENCE_DAYS);
  const latest = allSorted[allSorted.length - 1];

  const themeHits = new Map<string, JournalEntry[]>();
  for (const entry of allSorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      const list = themeHits.get(key) ?? [];
      list.push(entry);
      themeHits.set(key, list);
    }
  }

  for (const [themeKey, hits] of themeHits) {
    if (hits.length < 3) continue;
    const recent = hits.filter((e) => toDayKey(e.createdAt) >= cutoff);
    if (recent.length > 0) continue;

    const last = hits[hits.length - 1];
    const gap = daysBetweenKeys(toDayKey(last.createdAt), today);
    if (gap < ABSENCE_DAYS) continue;

    pushCandidate(notes, {
      id: `change-absent-${themeKey}`,
      kind: "concern_absent",
      text: "You had not mentioned this lately.",
      strength: 63 + Math.min(gap, 12) + hits.length,
      pastQuote: snippet(last),
      currentQuote: snippet(latest),
      pastDateLabel: formatRelativeDate(last.createdAt),
      currentDateLabel: formatRelativeDate(latest.createdAt),
      pastEntryId: last.id,
      entryId: latest.id,
    });
  }

  return notes;
}

function detectPhraseDisappeared(allSorted: JournalEntry[]): ChangeMomentNote[] {
  const notes: ChangeMomentNote[] = [];
  const today = toDayKey(new Date().toISOString());
  const cutoff = addDaysToKey(today, -ABSENCE_DAYS);
  const phrases = buildPhraseMemory(allSorted);
  const latest = allSorted[allSorted.length - 1];

  for (const record of phrases) {
    if (record.count < 3) continue;
    const lastOcc = record.occurrences[record.occurrences.length - 1];
    if (lastOcc.dateKey >= cutoff) continue;

    const gap = daysBetweenKeys(lastOcc.dateKey, today);
    if (gap < ABSENCE_DAYS) continue;

    const priorEntry = allSorted.find((e) => e.id === lastOcc.entryId);
    if (!priorEntry) continue;

    pushCandidate(notes, {
      id: `change-phrase-gone-${record.phrase}`,
      kind: "phrase_disappeared",
      text: "You had not mentioned this lately.",
      strength: 62 + Math.min(record.count, 5) + Math.min(gap, 8),
      pastQuote: snippet(priorEntry),
      currentQuote: snippet(latest),
      pastDateLabel: formatRelativeDate(priorEntry.createdAt),
      currentDateLabel: formatRelativeDate(latest.createdAt),
      pastEntryId: priorEntry.id,
      entryId: latest.id,
    });
  }

  return notes;
}

function recoveryToChangeNotes(
  current: JournalEntry,
  prior: JournalEntry[],
): ChangeMomentNote[] {
  return detectRecoveryCandidates(current, prior).map((r) => ({
    id: r.id,
    text: r.text,
    kind: r.kind,
    strength: r.strength,
    pastQuote: r.pastQuote,
    currentQuote: r.currentQuote,
    pastDateLabel: r.pastDateLabel,
    currentDateLabel: r.currentDateLabel,
    pastEntryId: r.pastEntryId,
    entryId: r.entryId,
  }));
}

function detectForAnchor(
  current: JournalEntry,
  prior: JournalEntry[],
  allSorted: JournalEntry[],
): ChangeMomentNote[] {
  return [
    ...recoveryToChangeNotes(current, prior),
    ...detectLanguageShifts(current, prior),
    ...detectAbsentConcerns(allSorted),
    ...detectPhraseDisappeared(allSorted),
  ];
}

const KIND_PRIORITY: ChangeMomentKind[] = [
  "recovery_after_topic",
  "calmer_return",
  "less_charged",
  "less_hedging",
  "more_direct",
  "concern_absent",
  "phrase_disappeared",
  "shorter_spiral",
  "future_forward",
  "you_sound_different",
];

function dedupeNotes(notes: ChangeMomentNote[]): ChangeMomentNote[] {
  const seen = new Set<string>();
  return notes
    .filter((n) => n.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((n) => {
      const key = `${n.kind}:${n.text.slice(0, 32)}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickBest(notes: ChangeMomentNote[], limit: number): ChangeMomentNote[] {
  const sorted = dedupeNotes(notes);
  const picked: ChangeMomentNote[] = [];
  const usedKinds = new Set<ChangeMomentKind>();

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

/** Detect quiet "you changed" moments grounded in language, not scores. */
export function buildChangeMomentsReport(
  entries: JournalEntry[],
  options: ChangeMomentsOptions,
): ChangeMomentsReport {
  const limit = options.limit ?? 1;
  const sorted = sortedEntries(entries);

  if (sorted.length < 3) {
    return { notes: [], hasData: false };
  }

  let anchor = sorted[sorted.length - 1];
  let prior = sorted.slice(0, -1);

  if (options.context === "entry" && options.entryId) {
    const idx = sorted.findIndex((e) => e.id === options.entryId);
    if (idx < 0) return { notes: [], hasData: false };
    anchor = sorted[idx];
    prior = sorted.slice(0, idx);
  }

  const notes = pickBest(detectForAnchor(anchor, prior, sorted), limit * 4);
  return { notes, hasData: notes.length > 0 };
}

export function changeMomentsToNotes(notes: ChangeMomentNote[]): MemoryNote[] {
  return notes.map((note) => ({
    id: note.id,
    text: note.text,
    category: "changed" as const,
    confidence: note.strength,
    pastQuote: note.pastQuote,
    currentQuote: note.currentQuote,
    pastDateLabel: note.pastDateLabel,
    currentDateLabel: note.currentDateLabel,
    pastEntryId: note.pastEntryId,
    entryId: note.entryId,
  }));
}

function applyChangeMomentsRarity(
  entries: JournalEntry[],
  notes: ChangeMomentNote[],
  surface: ResurfacingSurface,
  limit = 1,
): MemoryNote[] {
  return applyResurfacingRarity(
    notes.map((note) =>
      candidateFromChangeMomentNote(
        note,
        changeMomentsToNotes([note])[0],
        gapDaysBetweenEntries(entries, note.pastEntryId, note.entryId),
      ),
    ),
    { surface, limit, record: true, entries },
  );
}

export function entryChangeMomentsNotes(
  entries: JournalEntry[],
  entryId: string,
  limit = 1,
): MemoryNote[] {
  const report = buildChangeMomentsReport(entries, { context: "entry", entryId, limit });
  return applyMemoryHierarchy(
    applyChangeMomentsRarity(entries, report.notes, "entry", limit),
    entries,
    limit,
  );
}

export function timelineChangeMomentsNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  const report = buildChangeMomentsReport(entries, { context: "timeline", limit });
  return applyMemoryHierarchy(
    applyChangeMomentsRarity(entries, report.notes, "timeline", limit),
    entries,
    limit,
  );
}

export function monthlyChangeMomentsNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  const report = buildChangeMomentsReport(entries, { context: "monthly", limit });
  return applyMemoryHierarchy(
    applyChangeMomentsRarity(entries, report.notes, "monthly", limit),
    entries,
    limit,
  );
}

export function memoryChangeMomentsNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  const report = buildChangeMomentsReport(entries, { context: "memory", limit });
  return applyMemoryHierarchy(
    applyChangeMomentsRarity(entries, report.notes, "memory", limit),
    entries,
    limit,
  );
}
