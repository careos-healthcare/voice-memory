import { addDaysToKey, daysBetweenKeys, startOfWeekKey, toDayKey } from "@/lib/dates";
import {
  buildLanguageFingerprint,
  FAMILIARITY_COPY,
  fingerprintEvidence,
  type LanguageFingerprint,
  MIN_FINGERPRINT_ENTRIES,
} from "@/lib/memory/language-fingerprint";
import { hasTheme } from "@/lib/patterns/emotional-evolution";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import type {
  RhythmContext,
  RhythmKind,
  RhythmNote,
  RhythmReport,
} from "@/types/rhythm-memory";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const MIN_ENTRIES = 6;
const RHYTHM_MIN = 63;
const STRONG_MIN = 65;
const INTENSE_THRESHOLD = 6.5;
const CALM_THRESHOLD = 5;

export interface RhythmMemoryOptions {
  context: RhythmContext;
  limit?: number;
}

const CONTEXT_KIND_PRIORITY: Record<RhythmContext, RhythmKind[]> = {
  homepage: ["longer_calm", "longer_recovery", "after_busy_weeks"],
  timeline: ["longer_calm", "longer_recovery", "after_busy_weeks", "shorter_gap"],
  monthly: ["longer_calm", "longer_recovery", "after_busy_weeks"],
  memory: ["longer_calm", "longer_recovery", "after_busy_weeks"],
};

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function hasEvidence(
  item: Pick<RhythmNote, "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel">,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function pushCandidate(
  bucket: RhythmNote[],
  item: Omit<RhythmNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < RHYTHM_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function groupByWeek(sorted: JournalEntry[]): Map<string, JournalEntry[]> {
  const weeks = new Map<string, JournalEntry[]>();
  for (const entry of sorted) {
    const week = startOfWeekKey(toDayKey(entry.createdAt));
    const list = weeks.get(week) ?? [];
    list.push(entry);
    weeks.set(week, list);
  }
  return weeks;
}

function isBusyWeek(weekEntries: JournalEntry[]): boolean {
  if (weekEntries.length >= 3) return true;
  const avg = roundAvg(weekEntries.map((e) => e.reflection.emotionalIntensity));
  const max = Math.max(...weekEntries.map((e) => e.reflection.emotionalIntensity));
  return avg >= INTENSE_THRESHOLD || max >= 8;
}

function weekBefore(weekKey: string): string {
  return startOfWeekKey(addDaysToKey(weekKey, -7));
}

function detectAfterBusyWeeks(
  sorted: JournalEntry[],
  fingerprint: LanguageFingerprint,
): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const prior = sorted.slice(0, -1);
  const weeks = groupByWeek(sorted);
  const currentWeek = startOfWeekKey(toDayKey(current.createdAt));
  const prevWeekKey = weekBefore(currentWeek);
  const prevWeekEntries = weeks.get(prevWeekKey) ?? [];

  if (!isBusyWeek(prevWeekEntries)) return notes;

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorHits = prior.filter((e) => hasTheme(e, themeKey));
    if (priorHits.length < 2) continue;

    let afterBusy = 0;
    for (const hit of priorHits) {
      const hitWeek = startOfWeekKey(toDayKey(hit.createdAt));
      const beforeWeek = weeks.get(weekBefore(hitWeek)) ?? [];
      if (isBusyWeek(beforeWeek)) afterBusy += 1;
    }

    if (afterBusy < Math.ceil(priorHits.length * 0.55)) continue;

    const sample = priorHits[priorHits.length - 1];
    pushCandidate(notes, {
      id: `rhythm-busy-${themeKey}-${current.id}`,
      kind: "after_busy_weeks",
      text: "You came back after a heavy stretch.",
      strength: STRONG_MIN + afterBusy * 2,
      ...fingerprintEvidence(sample, current),
    });
  }

  return notes;
}

function detectShorterGap(
  sorted: JournalEntry[],
  fingerprint: LanguageFingerprint,
): RhythmNote[] {
  if (sorted.length < 4 || fingerprint.medianEntryGap < 2) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const prior = sorted[sorted.length - 2];
  const lastGap = daysBetweenKeys(toDayKey(prior.createdAt), toDayKey(current.createdAt));

  if (lastGap >= fingerprint.medianEntryGap * 0.65) return notes;
  if (fingerprint.medianEntryGap - lastGap < 2) return notes;

  pushCandidate(notes, {
    id: `rhythm-shorter-gap-${current.id}`,
    kind: "shorter_gap",
    text: FAMILIARITY_COPY.quickerReturn,
    strength: STRONG_MIN + Math.min(Math.round(fingerprint.medianEntryGap - lastGap), 8),
    ...fingerprintEvidence(prior, current),
  });

  return notes;
}

function detectLongerCalm(
  sorted: JournalEntry[],
  fingerprint: LanguageFingerprint,
): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES || fingerprint.typicalRecoveryDays <= 0) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const lastIntenseIdx = [...sorted]
    .map((e, idx) => ({ e, idx }))
    .reverse()
    .find(({ e }) => e.reflection.emotionalIntensity >= INTENSE_THRESHOLD);
  if (!lastIntenseIdx) return notes;

  const calmDays = daysBetweenKeys(
    toDayKey(lastIntenseIdx.e.createdAt),
    toDayKey(current.createdAt),
  );
  if (calmDays <= fingerprint.typicalRecoveryDays * 1.2) return notes;
  if (current.reflection.emotionalIntensity >= CALM_THRESHOLD + 0.5) return notes;

  pushCandidate(notes, {
    id: `rhythm-longer-calm-${current.id}`,
    kind: "longer_calm",
    text: FAMILIARITY_COPY.calmerLonger,
    strength: STRONG_MIN + Math.min(Math.round((calmDays - fingerprint.typicalRecoveryDays) / 3), 10),
    ...fingerprintEvidence(lastIntenseIdx.e, current),
  });

  return notes;
}

function detectLongerRecovery(
  sorted: JournalEntry[],
  fingerprint: LanguageFingerprint,
): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const prior = sorted.slice(0, -1);

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = fingerprint.themeReturnGap.get(themeKey);
    if (!typical || typical < 4) continue;

    const hits = prior.filter((e) => hasTheme(e, themeKey));
    if (hits.length < 2) continue;

    const lastGap = daysBetweenKeys(
      toDayKey(hits[hits.length - 1].createdAt),
      toDayKey(current.createdAt),
    );
    if (lastGap <= typical * 1.4) continue;

    pushCandidate(notes, {
      id: `rhythm-longer-recovery-${themeKey}-${current.id}`,
      kind: "longer_recovery",
      text: FAMILIARITY_COPY.slowerReturn,
      strength: STRONG_MIN + Math.min(Math.round(lastGap - typical), 10),
      ...fingerprintEvidence(hits[hits.length - 1], current),
    });
    break;
  }

  return notes;
}

function dedupeNotes(notes: RhythmNote[]): RhythmNote[] {
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

function pickForContext(
  candidates: RhythmNote[],
  context: RhythmContext,
  limit: number,
): RhythmNote[] {
  const sorted = dedupeNotes(candidates);
  const priority = CONTEXT_KIND_PRIORITY[context];
  const picked: RhythmNote[] = [];
  const usedKinds = new Set<RhythmKind>();

  for (const kind of priority) {
    if (picked.length >= limit) break;
    const match = sorted.find((n) => n.kind === kind && !usedKinds.has(kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
    }
  }

  return picked.slice(0, limit);
}

function collectCandidates(
  sorted: JournalEntry[],
  fingerprint: LanguageFingerprint,
): RhythmNote[] {
  return [
    ...detectAfterBusyWeeks(sorted, fingerprint),
    ...detectShorterGap(sorted, fingerprint),
    ...detectLongerCalm(sorted, fingerprint),
    ...detectLongerRecovery(sorted, fingerprint),
  ];
}

/** Detect quiet return pacing against your usual recovery. */
export function buildRhythmReport(
  entries: JournalEntry[],
  options: RhythmMemoryOptions,
): RhythmReport {
  const limit = options.limit ?? 1;
  const sorted = sortedEntries(entries);

  if (sorted.length < MIN_ENTRIES) {
    return { notes: [], hasData: false };
  }

  const history = sorted.slice(0, -1);
  if (history.length < MIN_FINGERPRINT_ENTRIES) {
    return { notes: [], hasData: false };
  }

  const fingerprint = buildLanguageFingerprint(history);
  if (!fingerprint) return { notes: [], hasData: false };

  const candidates = collectCandidates(sorted, fingerprint);
  const notes = pickForContext(candidates, options.context, limit);
  return { notes, hasData: notes.length > 0 };
}

export function rhythmToNotes(notes: RhythmNote[]): MemoryNote[] {
  return notes.map((note) => ({
    id: note.id,
    text: note.text,
    category: "changed" as const,
    confidence: note.strength,
    pastQuote: note.pastQuote,
    currentQuote: note.currentQuote,
    pastEntryId: note.pastEntryId,
    entryId: note.entryId,
    pastDateLabel: note.pastDateLabel,
    currentDateLabel: note.currentDateLabel,
  }));
}

export function homepageRhythmNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    rhythmToNotes(buildRhythmReport(entries, { context: "homepage", limit }).notes),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}

export function timelineRhythmNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    rhythmToNotes(buildRhythmReport(entries, { context: "timeline", limit }).notes),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}

export function monthlyRhythmNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    rhythmToNotes(buildRhythmReport(entries, { context: "monthly", limit }).notes),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}

export function memoryRhythmNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    rhythmToNotes(buildRhythmReport(entries, { context: "memory", limit }).notes),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}
