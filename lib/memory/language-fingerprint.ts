import { daysBetweenKeys, startOfWeekKey, toDayKey } from "@/lib/dates";
import { hasTheme } from "@/lib/patterns/emotional-evolution";
import { formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export const MIN_FINGERPRINT_ENTRIES = 5;
export const MIN_THEME_RETURNS = 2;
export const MIN_CIRCLE_SAMPLES = 2;

export const HEDGE_RE =
  /\b(maybe|sort of|kind of|probably|not sure|something|stuff|indirectly|i guess|vague)\b/gi;
export const DIRECT_RE =
  /\b(i will|decided|named|wrote down|mum|dad|mother|father|clearly|for sure|definitely|plan)\b/gi;
export const LOOP_RE =
  /\b(same loop|keep coming back|again before|that loop|same pattern|i keep|circling|around it)\b/i;

/** Human copy grounded in how you usually sound — not analysis. */
export const FAMILIARITY_COPY = {
  moreSettled: "You sound more settled here.",
  namedDirectly: "You named this directly this time.",
  usedToFeelHeavier: "This used to feel heavier.",
  stoppedCircling: "You stopped circling this.",
  slowerReturn: "You usually take longer to come back to this.",
  quickerReturn: "You came back sooner than you usually do.",
  calmerLonger: "Things stayed calmer for longer this time.",
} as const;

export interface LanguageFingerprint {
  avgIntensity: number;
  intensityP25: number;
  intensityP75: number;
  avgHedge: number;
  avgDirect: number;
  themeReturnGap: Map<string, number>;
  themeCircleRun: Map<string, number>;
  medianEntryGap: number;
  typicalRecoveryDays: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

export function entrySnippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

export function hedgeCount(entry: JournalEntry): number {
  return entry.transcript.match(HEDGE_RE)?.length ?? 0;
}

export function directCount(entry: JournalEntry): number {
  return entry.transcript.match(DIRECT_RE)?.length ?? 0;
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

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
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

function buildMedianEntryGap(sorted: JournalEntry[]): number {
  if (sorted.length < 2) return 0;
  const gaps = sorted.slice(1).map((entry, i) =>
    daysBetweenKeys(toDayKey(sorted[i].createdAt), toDayKey(entry.createdAt)),
  );
  return median(gaps);
}

function buildTypicalRecoveryDays(sorted: JournalEntry[]): number {
  const weeks = new Map<string, JournalEntry[]>();
  for (const entry of sorted) {
    const week = startOfWeekKey(toDayKey(entry.createdAt));
    const list = weeks.get(week) ?? [];
    list.push(entry);
    weeks.set(week, list);
  }

  const weekKeys = [...weeks.keys()].sort();
  const recoveryLengths: number[] = [];
  const intenseThreshold = 6.5;

  for (let i = 0; i < weekKeys.length - 1; i += 1) {
    const weekEntries = weeks.get(weekKeys[i]) ?? [];
    const weekAvg = roundAvg(weekEntries.map((e) => e.reflection.emotionalIntensity));
    if (weekAvg < intenseThreshold) continue;

    let calmDays = 0;
    for (let j = i + 1; j < weekKeys.length; j += 1) {
      const nextEntries = weeks.get(weekKeys[j]) ?? [];
      const nextAvg = roundAvg(nextEntries.map((e) => e.reflection.emotionalIntensity));
      if (nextAvg >= intenseThreshold) break;
      calmDays += 7;
    }
    if (calmDays > 0) recoveryLengths.push(calmDays);
  }

  return recoveryLengths.length >= 2 ? median(recoveryLengths) : 0;
}

/** Baseline for how you usually sound, return, hedge, and carry weight. */
export function buildLanguageFingerprint(history: JournalEntry[]): LanguageFingerprint | null {
  const sorted = sortedEntries(history);
  if (sorted.length < MIN_FINGERPRINT_ENTRIES) return null;

  const intensities = sorted.map((e) => e.reflection.emotionalIntensity);
  const hedges = sorted.map((e) => hedgeCount(e));
  const directs = sorted.map((e) => directCount(e));

  return {
    avgIntensity: roundAvg(intensities),
    intensityP25: percentile(intensities, 0.25),
    intensityP75: percentile(intensities, 0.75),
    avgHedge: roundAvg(hedges),
    avgDirect: roundAvg(directs),
    themeReturnGap: buildThemeReturnGaps(sorted),
    themeCircleRun: buildThemeCircleRuns(sorted),
    medianEntryGap: buildMedianEntryGap(sorted),
    typicalRecoveryDays: buildTypicalRecoveryDays(sorted),
  };
}

export function fingerprintEvidence(past: JournalEntry, current: JournalEntry) {
  return {
    pastQuote: entrySnippet(past),
    currentQuote: entrySnippet(current),
    pastDateLabel: formatRelativeDate(past.createdAt),
    currentDateLabel: formatRelativeDate(current.createdAt),
    pastEntryId: past.id,
    entryId: current.id,
  };
}

export function currentCircleRun(
  sorted: JournalEntry[],
  anchorIdx: number,
  themeKey: string,
): number {
  let start = anchorIdx;
  while (start > 0 && hasTheme(sorted[start - 1], themeKey)) {
    start -= 1;
  }
  return anchorIdx - start + 1;
}

export function isLooping(entry: JournalEntry): boolean {
  return LOOP_RE.test(entry.transcript) || hedgeCount(entry) >= 2;
}
