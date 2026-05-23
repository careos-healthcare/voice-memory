import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { hasTheme } from "@/lib/patterns/emotional-evolution";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type {
  FamiliarityContext,
  FamiliarityKind,
  FamiliarityNote,
  FamiliarityReport,
} from "@/types/familiarity";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const MIN_BASELINE_ENTRIES = 5;
const FAMILIAR_MIN = 60;
const MIN_THEME_RETURNS = 2;
const MIN_CIRCLE_SAMPLES = 2;

const HEDGE_RE =
  /\b(maybe|sort of|kind of|probably|not sure|something|stuff|indirectly|i guess)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|mum|dad|mother|father|clearly|for sure|definitely|plan)\b/gi;
const LOOP_RE =
  /\b(same loop|keep coming back|again before|that loop|same pattern|i keep)\b/i;

export interface FamiliarityOptions {
  context: FamiliarityContext;
  entryId?: string;
  limit?: number;
}

interface FamiliarityBaseline {
  avgIntensity: number;
  intensityP25: number;
  intensityP75: number;
  avgHedge: number;
  avgDirect: number;
  themeReturnGap: Map<string, number>;
  themeCircleRun: Map<string, number>;
}

const CONTEXT_KIND_PRIORITY: Record<FamiliarityContext, FamiliarityKind[]> = {
  homepage: [
    "more_settled_than_usual",
    "more_direct_than_usual",
    "quicker_return",
    "longer_circle_usual",
  ],
  entry: [
    "more_settled_than_usual",
    "more_direct_than_usual",
    "quicker_return",
    "longer_circle_usual",
    "unusual_tension",
    "unusual_loop",
  ],
  timeline: [
    "quicker_return",
    "longer_circle_usual",
    "more_settled_than_usual",
    "more_direct_than_usual",
  ],
  monthly: [
    "more_settled_than_usual",
    "more_direct_than_usual",
    "longer_circle_usual",
    "quicker_return",
  ],
  memory: [
    "longer_circle_usual",
    "quicker_return",
    "more_settled_than_usual",
    "more_direct_than_usual",
  ],
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

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * p));
  return sorted[idx];
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
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
  item: Pick<FamiliarityNote, "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel">,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function pushCandidate(
  bucket: FamiliarityNote[],
  item: Omit<FamiliarityNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < FAMILIAR_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function buildThemeReturnGaps(sorted: JournalEntry[]): Map<string, number> {
  const lastDay = new Map<string, string>();
  const gaps = new Map<string, number[]>();

  for (const entry of sorted) {
    const day = toDayKey(entry.createdAt);
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      const prev = lastDay.get(key);
      if (prev) {
        const gap = daysBetweenKeys(prev, day);
        if (gap > 0) {
          const list = gaps.get(key) ?? [];
          list.push(gap);
          gaps.set(key, list);
        }
      }
      lastDay.set(key, day);
    }
  }

  const avg = new Map<string, number>();
  for (const [theme, list] of gaps) {
    if (list.length >= MIN_THEME_RETURNS) {
      avg.set(theme, roundAvg(list));
    }
  }
  return avg;
}

function buildThemeCircleRuns(sorted: JournalEntry[]): Map<string, number> {
  const runs = new Map<string, number[]>();
  let i = 0;

  while (i < sorted.length) {
    const themes = new Set(sorted[i].reflection.recurringThemes.map((t) => t.toLowerCase()));
    if (themes.size === 0) {
      i += 1;
      continue;
    }

    const runThemes = new Set(themes);
    let j = i + 1;
    while (j < sorted.length) {
      const nextThemes = sorted[j].reflection.recurringThemes.map((t) => t.toLowerCase());
      const overlap = nextThemes.some((t) => runThemes.has(t));
      if (!overlap) break;
      for (const t of nextThemes) runThemes.add(t);
      j += 1;
    }

    const runLength = j - i;
    if (runLength >= 1) {
      for (const theme of runThemes) {
        const list = runs.get(theme) ?? [];
        list.push(runLength);
        runs.set(theme, list);
      }
    }
    i = j;
  }

  const avg = new Map<string, number>();
  for (const [theme, list] of runs) {
    if (list.length >= MIN_CIRCLE_SAMPLES) {
      avg.set(theme, roundAvg(list));
    }
  }
  return avg;
}

function buildBaseline(history: JournalEntry[]): FamiliarityBaseline | null {
  if (history.length < MIN_BASELINE_ENTRIES) return null;

  const intensities = history.map((e) => e.reflection.emotionalIntensity);
  const hedges = history.map((e) => countMatches(e.transcript, HEDGE_RE));
  const directs = history.map((e) => countMatches(e.transcript, DIRECT_RE));

  return {
    avgIntensity: roundAvg(intensities),
    intensityP25: percentile(intensities, 0.25),
    intensityP75: percentile(intensities, 0.75),
    avgHedge: roundAvg(hedges),
    avgDirect: roundAvg(directs),
    themeReturnGap: buildThemeReturnGaps(history),
    themeCircleRun: buildThemeCircleRuns(history),
  };
}

function currentCircleRun(sorted: JournalEntry[], anchorIdx: number, themeKey: string): number {
  let start = anchorIdx;
  while (start > 0 && hasTheme(sorted[start - 1], themeKey)) {
    start -= 1;
  }
  return anchorIdx - start + 1;
}

function detectMoreSettled(
  current: JournalEntry,
  baseline: FamiliarityBaseline,
  history: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  const intensity = current.reflection.emotionalIntensity;
  const delta = baseline.avgIntensity - intensity;
  const belowUsual = intensity <= baseline.intensityP25 - 0.3 || delta >= 1.5;
  if (!belowUsual) return notes;

  const calmerPrior = [...history]
    .reverse()
    .find((e) => e.reflection.emotionalIntensity >= baseline.avgIntensity);
  if (!calmerPrior) return notes;

  pushCandidate(notes, {
    id: `familiar-settled-${current.id}`,
    kind: "more_settled_than_usual",
    text: "This sounds more settled than usual.",
    strength: 62 + Math.min(Math.round(delta * 3), 12),
    ...evidence(calmerPrior, current),
  });

  return notes;
}

function detectMoreDirect(
  current: JournalEntry,
  baseline: FamiliarityBaseline,
  history: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  const hedge = countMatches(current.transcript, HEDGE_RE);
  const direct = countMatches(current.transcript, DIRECT_RE);
  const directDelta = direct - baseline.avgDirect;
  const hedgeDelta = baseline.avgHedge - hedge;

  if (directDelta < 1 || direct <= baseline.avgDirect) return notes;
  if (hedgeDelta < 0 && hedge > baseline.avgHedge) return notes;

  const hedgedPrior = [...history]
    .reverse()
    .find((e) => countMatches(e.transcript, HEDGE_RE) >= baseline.avgHedge);
  if (!hedgedPrior) return notes;

  pushCandidate(notes, {
    id: `familiar-direct-${current.id}`,
    kind: "more_direct_than_usual",
    text: "This feels more direct than your usual wording.",
    strength: 61 + directDelta * 4 + Math.max(hedgeDelta, 0) * 2,
    ...evidence(hedgedPrior, current),
  });

  return notes;
}

function detectQuickerReturn(
  current: JournalEntry,
  prior: JournalEntry[],
  baseline: FamiliarityBaseline,
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  const currentDay = toDayKey(current.createdAt);

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = baseline.themeReturnGap.get(themeKey);
    if (!typical || typical < 3) continue;

    const priorMatches = prior.filter((e) => hasTheme(e, themeKey));
    if (priorMatches.length === 0) continue;

    const lastPrior = priorMatches[priorMatches.length - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), currentDay);
    if (gap <= 0 || gap >= typical * 0.65) continue;

    pushCandidate(notes, {
      id: `familiar-quicker-${themeKey}-${current.id}`,
      kind: "quicker_return",
      text: "You returned to this more quickly this time.",
      strength: 63 + Math.min(typical - gap, 10) + (priorMatches.length >= 2 ? 3 : 0),
      ...evidence(lastPrior, current),
    });
  }

  return notes;
}

function detectLongerCircleUsual(
  current: JournalEntry,
  sorted: JournalEntry[],
  anchorIdx: number,
  baseline: FamiliarityBaseline,
  prior: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = baseline.themeCircleRun.get(themeKey);
    if (!typical || typical < 2) continue;

    const run = currentCircleRun(sorted, anchorIdx, themeKey);
    if (run >= typical - 0.5) continue;

    const earlierRun = prior.filter((e) => hasTheme(e, themeKey));
    if (earlierRun.length < 2) continue;

    const sample = earlierRun.find(
      (e) =>
        e.reflection.emotionalIntensity >= current.reflection.emotionalIntensity &&
        countMatches(e.transcript, HEDGE_RE) >= countMatches(current.transcript, HEDGE_RE),
    );
    if (!sample) continue;

    pushCandidate(notes, {
      id: `familiar-circle-${themeKey}-${current.id}`,
      kind: "longer_circle_usual",
      text: "You usually circle this topic longer.",
      strength: 62 + Math.min(Math.round(typical - run) * 3, 10),
      ...evidence(sample, current),
    });
  }

  return notes;
}

function detectUnusualTension(
  current: JournalEntry,
  baseline: FamiliarityBaseline,
  history: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  const intensity = current.reflection.emotionalIntensity;
  const delta = intensity - baseline.avgIntensity;
  const aboveUsual = intensity >= baseline.intensityP75 + 0.8 || delta >= 1.8;
  if (!aboveUsual) return notes;

  const calmerPrior = [...history]
    .reverse()
    .find((e) => e.reflection.emotionalIntensity <= baseline.avgIntensity);
  if (!calmerPrior) return notes;

  pushCandidate(notes, {
    id: `familiar-tension-${current.id}`,
    kind: "unusual_tension",
    text: "This carries more weight than you usually leave here.",
    strength: 61 + Math.min(Math.round(delta * 3), 12),
    ...evidence(calmerPrior, current),
  });

  return notes;
}

function detectUnusualLoop(
  current: JournalEntry,
  sorted: JournalEntry[],
  anchorIdx: number,
  baseline: FamiliarityBaseline,
  prior: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  if (!LOOP_RE.test(current.transcript)) return notes;

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = baseline.themeCircleRun.get(themeKey);
    if (!typical) continue;

    const run = currentCircleRun(sorted, anchorIdx, themeKey);
    if (run <= typical + 0.5) continue;

    const loopPrior = [...prior]
      .reverse()
      .find(
        (e) =>
          hasTheme(e, themeKey) &&
          (LOOP_RE.test(e.transcript) || countMatches(e.transcript, HEDGE_RE) >= baseline.avgHedge),
      );
    if (!loopPrior) continue;

    pushCandidate(notes, {
      id: `familiar-loop-${themeKey}-${current.id}`,
      kind: "unusual_loop",
      text: "You usually take longer before this comes back.",
      strength: 62 + Math.min(Math.round(run - typical) * 3, 10),
      ...evidence(loopPrior, current),
    });
  }

  return notes;
}

function dedupeNotes(notes: FamiliarityNote[]): FamiliarityNote[] {
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
  candidates: FamiliarityNote[],
  context: FamiliarityContext,
  limit: number,
): FamiliarityNote[] {
  const sorted = dedupeNotes(candidates);
  const priority = CONTEXT_KIND_PRIORITY[context];
  const picked: FamiliarityNote[] = [];
  const usedKinds = new Set<FamiliarityKind>();

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

function collectCandidates(
  sorted: JournalEntry[],
  anchorIdx: number,
  baseline: FamiliarityBaseline,
): FamiliarityNote[] {
  const current = sorted[anchorIdx];
  const prior = sorted.slice(0, anchorIdx);
  const history = prior;

  return [
    ...detectMoreSettled(current, baseline, history),
    ...detectMoreDirect(current, baseline, history),
    ...detectQuickerReturn(current, prior, baseline),
    ...detectLongerCircleUsual(current, sorted, anchorIdx, baseline, prior),
    ...detectUnusualTension(current, baseline, history),
    ...detectUnusualLoop(current, sorted, anchorIdx, baseline, prior),
  ];
}

/** Detect quiet familiarity — how this reflection sits against your usual patterns. */
export function buildFamiliarityReport(
  entries: JournalEntry[],
  options: FamiliarityOptions,
): FamiliarityReport {
  const limit = options.limit ?? 1;
  const sorted = sortedEntries(entries);

  if (sorted.length < MIN_BASELINE_ENTRIES + 1) {
    return { notes: [], hasData: false };
  }

  let anchorIdx = sorted.length - 1;
  if (options.context === "entry" && options.entryId) {
    const idx = sorted.findIndex((e) => e.id === options.entryId);
    if (idx < 0) return { notes: [], hasData: false };
    anchorIdx = idx;
  }

  const history = sorted.slice(0, anchorIdx);
  if (history.length < MIN_BASELINE_ENTRIES) {
    return { notes: [], hasData: false };
  }

  const baseline = buildBaseline(history);
  if (!baseline) return { notes: [], hasData: false };

  const candidates = collectCandidates(sorted, anchorIdx, baseline);
  const notes = pickForContext(candidates, options.context, limit);
  return { notes, hasData: notes.length > 0 };
}

export function familiarityToNotes(notes: FamiliarityNote[]): MemoryNote[] {
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

export function homepageFamiliarityNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return familiarityToNotes(buildFamiliarityReport(entries, { context: "homepage", limit }).notes);
}

export function entryFamiliarityNotes(
  entries: JournalEntry[],
  entryId: string,
  limit = 1,
): MemoryNote[] {
  return familiarityToNotes(
    buildFamiliarityReport(entries, { context: "entry", entryId, limit }).notes,
  );
}

export function timelineFamiliarityNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return familiarityToNotes(buildFamiliarityReport(entries, { context: "timeline", limit }).notes);
}

export function monthlyFamiliarityNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return familiarityToNotes(buildFamiliarityReport(entries, { context: "monthly", limit }).notes);
}

export function memoryFamiliarityNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return familiarityToNotes(buildFamiliarityReport(entries, { context: "memory", limit }).notes);
}
