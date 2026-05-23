import { addDaysToKey, daysBetweenKeys, startOfWeekKey, toDayKey } from "@/lib/dates";
import { hasTheme } from "@/lib/patterns/emotional-evolution";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type {
  RhythmContext,
  RhythmKind,
  RhythmNote,
  RhythmReport,
} from "@/types/rhythm-memory";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";

const MIN_ENTRIES = 6;
const RHYTHM_MIN = 60;
const MIN_WEEK_SAMPLES = 2;
const INTENSE_THRESHOLD = 6.5;
const CALM_THRESHOLD = 5;

export interface RhythmMemoryOptions {
  context: RhythmContext;
  limit?: number;
}

const CONTEXT_KIND_PRIORITY: Record<RhythmContext, RhythmKind[]> = {
  homepage: ["after_busy_weeks", "end_of_week_return", "longer_calm", "shorter_gap"],
  timeline: ["shorter_gap", "longer_calm", "weekly_loop", "after_busy_weeks", "end_of_week_return"],
  monthly: ["longer_calm", "after_busy_weeks", "tension_interval", "weekly_loop", "longer_recovery"],
  memory: ["weekly_loop", "after_busy_weeks", "end_of_week_return", "late_night_weekend", "rhythm_disruption"],
};

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

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function dayOfWeek(iso: string): number {
  return new Date(iso).getDay();
}

function hourOf(iso: string): number {
  return new Date(iso).getHours();
}

function isLateWeek(dow: number): boolean {
  return dow === 0 || dow >= 4;
}

function isWeekend(dow: number): boolean {
  return dow === 0 || dow === 6;
}

function isLateNight(hour: number): boolean {
  return hour >= 21 || hour < 5;
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

function detectAfterBusyWeeks(sorted: JournalEntry[]): RhythmNote[] {
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
      text: "This tends to return after busy weeks.",
      strength: 63 + afterBusy * 2 + (prevWeekEntries.length >= 3 ? 4 : 0),
      ...evidence(sample, current),
    });
  }

  return notes;
}

function detectShorterGap(sorted: JournalEntry[]): RhythmNote[] {
  if (sorted.length < 4) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const prior = sorted[sorted.length - 2];
  const gaps = sorted.slice(1).map((e, i) =>
    daysBetweenKeys(toDayKey(sorted[i].createdAt), toDayKey(e.createdAt)),
  );
  const priorGaps = gaps.slice(0, -1);
  const lastGap = gaps[gaps.length - 1];
  const typical = median(priorGaps);

  if (typical < 2 || lastGap >= typical * 0.65) return notes;
  if (typical - lastGap < 2) return notes;

  pushCandidate(notes, {
    id: `rhythm-shorter-gap-${current.id}`,
    kind: "shorter_gap",
    text: "The gap between these entries became shorter.",
    strength: 62 + Math.min(Math.round(typical - lastGap), 8),
    ...evidence(prior, current),
  });

  return notes;
}

function detectLongerCalm(sorted: JournalEntry[]): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const weeks = groupByWeek(sorted);
  const weekKeys = [...weeks.keys()].sort();
  const recoveryLengths: number[] = [];

  for (let i = 0; i < weekKeys.length - 1; i += 1) {
    const weekEntries = weeks.get(weekKeys[i]) ?? [];
    const weekAvg = roundAvg(weekEntries.map((e) => e.reflection.emotionalIntensity));
    if (weekAvg < INTENSE_THRESHOLD) continue;

    let calmDays = 0;
    for (let j = i + 1; j < weekKeys.length; j += 1) {
      const nextEntries = weeks.get(weekKeys[j]) ?? [];
      const nextAvg = roundAvg(nextEntries.map((e) => e.reflection.emotionalIntensity));
      if (nextAvg >= INTENSE_THRESHOLD) break;
      calmDays += 7;
    }
    if (calmDays > 0) recoveryLengths.push(calmDays);
  }

  if (recoveryLengths.length < MIN_WEEK_SAMPLES) return notes;

  const typicalRecovery = median(recoveryLengths);
  const current = sorted[sorted.length - 1];
  const recentWeeks = weekKeys.slice(-3);
  const recentIntense = recentWeeks.some((wk) => {
    const entries = weeks.get(wk) ?? [];
    return roundAvg(entries.map((e) => e.reflection.emotionalIntensity)) >= INTENSE_THRESHOLD;
  });
  if (recentIntense) return notes;

  const lastIntenseIdx = [...sorted]
    .map((e, idx) => ({ e, idx }))
    .reverse()
    .find(({ e }) => e.reflection.emotionalIntensity >= INTENSE_THRESHOLD);
  if (!lastIntenseIdx) return notes;

  const calmDays = daysBetweenKeys(
    toDayKey(lastIntenseIdx.e.createdAt),
    toDayKey(current.createdAt),
  );
  if (calmDays <= typicalRecovery * 1.25 || current.reflection.emotionalIntensity >= CALM_THRESHOLD) {
    return notes;
  }

  pushCandidate(notes, {
    id: `rhythm-longer-calm-${current.id}`,
    kind: "longer_calm",
    text: "Things stayed calmer for longer this time.",
    strength: 62 + Math.min(Math.round((calmDays - typicalRecovery) / 3), 10),
    ...evidence(lastIntenseIdx.e, current),
  });

  return notes;
}

function detectEndOfWeekReturn(sorted: JournalEntry[]): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const currentDow = dayOfWeek(current.createdAt);
  if (!isLateWeek(currentDow)) return notes;

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const hits = sorted.filter((e) => hasTheme(e, themeKey));
    if (hits.length < 3) continue;

    const lateHits = hits.filter((e) => isLateWeek(dayOfWeek(e.createdAt)));
    if (lateHits.length < 3 || lateHits.length / hits.length < 0.65) continue;

    const sample = lateHits[lateHits.length - 2] ?? lateHits[0];
    pushCandidate(notes, {
      id: `rhythm-eow-${themeKey}-${current.id}`,
      kind: "end_of_week_return",
      text: "This usually returns at the end of the week.",
      strength: 63 + lateHits.length * 2,
      ...evidence(sample, current),
    });
  }

  return notes;
}

function detectWeeklyLoop(sorted: JournalEntry[]): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const weeks = groupByWeek(sorted);
  const weekKeys = [...weeks.keys()].sort();

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const themeWeeks = weekKeys.filter((wk) =>
      (weeks.get(wk) ?? []).some((e) => hasTheme(e, themeKey)),
    );
    if (themeWeeks.length < 3) continue;

    let consecutive = 1;
    let maxConsecutive = 1;
    for (let i = 1; i < themeWeeks.length; i += 1) {
      const gap = daysBetweenKeys(themeWeeks[i - 1], themeWeeks[i]);
      if (gap <= 10) {
        consecutive += 1;
        maxConsecutive = Math.max(maxConsecutive, consecutive);
      } else {
        consecutive = 1;
      }
    }

    if (maxConsecutive < 3) continue;

    const priorHits = sorted.filter((e) => hasTheme(e, themeKey) && e.id !== current.id);
    const sample = priorHits[priorHits.length - 1];
    if (!sample) continue;

    pushCandidate(notes, {
      id: `rhythm-weekly-${themeKey}-${current.id}`,
      kind: "weekly_loop",
      text: "This keeps coming back on a weekly rhythm.",
      strength: 61 + maxConsecutive * 3,
      ...evidence(sample, current),
    });
  }

  return notes;
}

function detectLongerRecovery(sorted: JournalEntry[]): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const prior = sorted.slice(0, -1);

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const hits = prior.filter((e) => hasTheme(e, themeKey));
    if (hits.length < 3) continue;

    const gaps: number[] = [];
    for (let i = 1; i < hits.length; i += 1) {
      gaps.push(daysBetweenKeys(toDayKey(hits[i - 1].createdAt), toDayKey(hits[i].createdAt)));
    }
    const typical = median(gaps);
    const lastGap = daysBetweenKeys(
      toDayKey(hits[hits.length - 1].createdAt),
      toDayKey(current.createdAt),
    );

    if (typical < 4 || lastGap <= typical * 1.45) continue;

    pushCandidate(notes, {
      id: `rhythm-longer-recovery-${themeKey}-${current.id}`,
      kind: "longer_recovery",
      text: "This took longer than usual to come back.",
      strength: 61 + Math.min(Math.round(lastGap - typical), 10),
      ...evidence(hits[hits.length - 1], current),
    });
  }

  return notes;
}

function detectTensionInterval(sorted: JournalEntry[]): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const intense = sorted.filter((e) => e.reflection.emotionalIntensity >= 7);
  if (intense.length < 3) return notes;

  const gaps: number[] = [];
  for (let i = 1; i < intense.length; i += 1) {
    gaps.push(
      daysBetweenKeys(toDayKey(intense[i - 1].createdAt), toDayKey(intense[i].createdAt)),
    );
  }

  const typical = median(gaps);
  if (typical < 5 || typical > 12) return notes;

  const spread = Math.max(...gaps) - Math.min(...gaps);
  if (spread > 5) return notes;

  const lastGap = daysBetweenKeys(
    toDayKey(intense[intense.length - 2].createdAt),
    toDayKey(current.createdAt),
  );
  if (Math.abs(lastGap - typical) > 3) return notes;

  pushCandidate(notes, {
    id: `rhythm-tension-interval-${current.id}`,
    kind: "tension_interval",
    text: "This tends to return after busy weeks.",
    strength: 60 + intense.length * 2,
    ...evidence(intense[intense.length - 2], current),
  });

  return notes;
}

function detectRhythmDisruption(sorted: JournalEntry[]): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const prior = sorted.slice(0, -1);
  const gaps = sorted.slice(1).map((e, i) =>
    daysBetweenKeys(toDayKey(sorted[i].createdAt), toDayKey(e.createdAt)),
  );
  const typical = median(gaps.slice(0, -1));
  const lastGap = gaps[gaps.length - 1];

  if (typical < 3 || lastGap <= typical * 1.6) return notes;

  const priorEntry = prior[prior.length - 1];
  pushCandidate(notes, {
    id: `rhythm-disruption-${current.id}`,
    kind: "rhythm_disruption",
    text: "The pace between entries shifted here.",
    strength: 61 + Math.min(Math.round(lastGap - typical), 8),
    ...evidence(priorEntry, current),
  });

  return notes;
}

function detectLateNightWeekend(sorted: JournalEntry[]): RhythmNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: RhythmNote[] = [];
  const current = sorted[sorted.length - 1];
  const dow = dayOfWeek(current.createdAt);
  const hour = hourOf(current.createdAt);

  if (!isWeekend(dow) && !isLateNight(hour)) return notes;
  if (current.reflection.emotionalIntensity < 5.5) return notes;

  const matches = sorted.filter((e) => {
    const eDow = dayOfWeek(e.createdAt);
    const eHour = hourOf(e.createdAt);
    return (
      (isWeekend(eDow) || isLateNight(eHour)) &&
      e.reflection.emotionalIntensity >= 5.5
    );
  });

  if (matches.length < 3) return notes;

  const sample = matches[matches.length - 2];
  pushCandidate(notes, {
    id: `rhythm-late-weekend-${current.id}`,
    kind: "late_night_weekend",
    text: "This often shows up late in the week.",
    strength: 62 + matches.length * 2,
    ...evidence(sample, current),
  });

  return notes;
}

function dedupeNotes(notes: RhythmNote[]): RhythmNote[] {
  const seen = new Set<string>();
  return notes
    .filter((n) => n.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((n) => {
      const key = `${n.kind}:${n.text}`;
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

  for (const note of sorted) {
    if (picked.length >= limit) break;
    if (picked.some((p) => p.id === note.id)) continue;
    picked.push(note);
  }

  return picked.slice(0, limit);
}

function collectCandidates(sorted: JournalEntry[]): RhythmNote[] {
  return [
    ...detectAfterBusyWeeks(sorted),
    ...detectShorterGap(sorted),
    ...detectLongerCalm(sorted),
    ...detectEndOfWeekReturn(sorted),
    ...detectWeeklyLoop(sorted),
    ...detectLongerRecovery(sorted),
    ...detectTensionInterval(sorted),
    ...detectRhythmDisruption(sorted),
    ...detectLateNightWeekend(sorted),
  ];
}

/** Detect quiet emotional rhythm across reflections. */
export function buildRhythmReport(
  entries: JournalEntry[],
  options: RhythmMemoryOptions,
): RhythmReport {
  const limit = options.limit ?? 1;
  const sorted = sortedEntries(entries);

  if (sorted.length < MIN_ENTRIES) {
    return { notes: [], hasData: false };
  }

  const candidates = collectCandidates(sorted);
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
  );
}

export function timelineRhythmNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    rhythmToNotes(buildRhythmReport(entries, { context: "timeline", limit }).notes),
    entries,
    limit,
  );
}

export function monthlyRhythmNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    rhythmToNotes(buildRhythmReport(entries, { context: "monthly", limit }).notes),
    entries,
    limit,
  );
}

export function memoryRhythmNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    rhythmToNotes(buildRhythmReport(entries, { context: "memory", limit }).notes),
    entries,
    limit,
  );
}
