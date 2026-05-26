import { addDaysToKey, todayKey, toDayKey } from "@/lib/dates";
import { getPrimaryObservation } from "@/lib/observation-language";
import { getEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { WeeklyReflectionPayload } from "@/types/weekly";

export interface RankedItem {
  label: string;
  count: number;
}

export interface DayIntensityPoint {
  dayKey: string;
  label: string;
  shortLabel: string;
  avgIntensity: number;
  entryCount: number;
}

export interface DayEntryPoint {
  dayKey: string;
  label: string;
  shortLabel: string;
  count: number;
}

export interface WeekSliceStats {
  startDayKey: string;
  endDayKey: string;
  entryCount: number;
  dominantEmotions: RankedItem[];
  repeatedConcerns: RankedItem[];
  repeatedEntities: RankedItem[];
  recurringThemes: RankedItem[];
  avgIntensity: number | null;
  intensityByDay: DayIntensityPoint[];
  entryTimeline: DayEntryPoint[];
}

export interface WeekComparison {
  entryCount: { thisWeek: number; lastWeek: number };
  avgIntensity: { thisWeek: number | null; lastWeek: number | null };
  dominantEmotion: { thisWeek: string | null; lastWeek: string | null };
  topTheme: { thisWeek: string | null; lastWeek: string | null };
}

export type EmotionalShiftDirection =
  | "calmer"
  | "intenser"
  | "stable"
  | "mixed"
  | "unknown";

export interface EmotionalShift {
  direction: EmotionalShiftDirection;
  intensityDelta: number | null;
  label: string;
  detail: string;
}

export interface WeeklyIntelligenceReport {
  weekEndingKey: string;
  weekRangeLabel: string;
  previousWeekRangeLabel: string;
  generatedAt: string;
  thisWeek: WeekSliceStats;
  lastWeek: WeekSliceStats;
  comparison: WeekComparison;
  emotionalShift: EmotionalShift;
  hasData: boolean;
}

const STOPWORDS = new Set([
  "the",
  "and",
  "for",
  "that",
  "this",
  "with",
  "from",
  "your",
  "have",
  "been",
  "were",
  "they",
  "what",
  "when",
  "where",
  "which",
  "while",
  "about",
  "into",
  "just",
  "like",
  "really",
  "very",
  "also",
  "then",
  "than",
  "them",
  "their",
  "there",
  "would",
  "could",
  "should",
  "because",
  "something",
  "someone",
  "today",
  "yesterday",
  "tomorrow",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
  "january",
  "february",
  "march",
  "april",
  "may",
  "june",
  "july",
  "august",
  "september",
  "october",
  "november",
  "december",
]);

const NAME_STOPWORDS = new Set([
  "I",
  "The",
  "This",
  "That",
  "What",
  "When",
  "Where",
  "How",
  "Why",
  "But",
  "And",
  "Or",
  "So",
  "If",
  "Then",
  "Just",
  "Really",
  "Today",
  "Yesterday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
]);

const RELATIONSHIP_PATTERN =
  /\bmy\s+(mom|mother|dad|father|parent|parents|partner|wife|husband|spouse|boss|manager|friend|friends|therapist|doctor|sister|brother|son|daughter|kids|child|children|colleague|coworker|team)\b/gi;

function countMap(items: string[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const item of items) {
    const key = item.trim().toLowerCase();
    if (!key || key.length < 2) continue;
    map.set(key, (map.get(key) ?? 0) + 1);
  }
  return map;
}

function topItems(map: Map<string, number>, limit = 5): RankedItem[] {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([label, count]) => ({ label, count }));
}

function formatDayLabel(dayKey: string, short = false): string {
  const [y, m, d] = dayKey.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  if (short) {
    return new Intl.DateTimeFormat("en-US", { weekday: "narrow" }).format(date);
  }
  return new Intl.DateTimeFormat("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  }).format(date);
}

function formatRangeLabel(startKey: string, endKey: string): string {
  const [y1, m1, d1] = startKey.split("-").map(Number);
  const [y2, m2, d2] = endKey.split("-").map(Number);
  const start = new Date(y1, m1 - 1, d1);
  const end = new Date(y2, m2 - 1, d2);
  const fmt = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" });
  return `${fmt.format(start)} – ${fmt.format(end)}`;
}

function entriesInRange(
  entries: JournalEntry[],
  startKey: string,
  endKey: string,
): JournalEntry[] {
  return entries.filter((e) => {
    const key = toDayKey(e.createdAt);
    return key >= startKey && key <= endKey;
  });
}

function tokenizeConcern(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^\w\s'-]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 3 && !STOPWORDS.has(w));
}

function extractConcerns(weekEntries: JournalEntry[]): RankedItem[] {
  const counts = new Map<string, number>();

  for (const entry of weekEntries) {
    const sources = [
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
      ...(entry.reflection.patternObservations ?? []),
      entry.transcript.slice(0, 200),
    ].filter(Boolean) as string[];

    for (const source of sources) {
      const phrase = source.trim().toLowerCase();
      if (phrase.length < 8) continue;
      counts.set(phrase.slice(0, 80), (counts.get(phrase.slice(0, 80)) ?? 0) + 1);

      for (const token of tokenizeConcern(source)) {
        counts.set(token, (counts.get(token) ?? 0) + 1);
      }
    }
  }

  return topItems(counts, 6);
}

function extractEntities(weekEntries: JournalEntry[]): RankedItem[] {
  const counts = new Map<string, number>();

  for (const entry of weekEntries) {
    const text = `${entry.transcript}\n${entry.reflection.concreteObservation ?? ""}`;

    for (const match of text.matchAll(RELATIONSHIP_PATTERN)) {
      const label = match[0].toLowerCase();
      counts.set(label, (counts.get(label) ?? 0) + 1);
    }

    const capitalized = text.match(/\b[A-Z][a-z]{2,}\b/g) ?? [];
    for (const word of capitalized) {
      if (NAME_STOPWORDS.has(word)) continue;
      counts.set(word, (counts.get(word) ?? 0) + 1);
    }
  }

  return topItems(counts, 6);
}

function extractThemes(weekEntries: JournalEntry[]): RankedItem[] {
  const themes = weekEntries.flatMap((e) => e.reflection.recurringThemes);
  return topItems(countMap(themes.map((t) => t.trim())), 8);
}

function extractEmotions(weekEntries: JournalEntry[]): RankedItem[] {
  const moods = weekEntries.map((e) => e.reflection.mood.trim());
  return topItems(countMap(moods), 5);
}

function avgIntensity(weekEntries: JournalEntry[]): number | null {
  if (weekEntries.length === 0) return null;
  const sum = weekEntries.reduce(
    (acc, e) => acc + e.reflection.emotionalIntensity,
    0,
  );
  return Math.round((sum / weekEntries.length) * 10) / 10;
}

function buildDaySeries(
  weekEntries: JournalEntry[],
  startKey: string,
  endKey: string,
): { intensity: DayIntensityPoint[]; entries: DayEntryPoint[] } {
  const intensity: DayIntensityPoint[] = [];
  const entries: DayEntryPoint[] = [];

  let cursor = startKey;
  while (cursor <= endKey) {
    const dayEntries = weekEntries.filter((e) => toDayKey(e.createdAt) === cursor);
    const label = formatDayLabel(cursor);
    const shortLabel = formatDayLabel(cursor, true);

    if (dayEntries.length > 0) {
      const sum = dayEntries.reduce(
        (acc, e) => acc + e.reflection.emotionalIntensity,
        0,
      );
      intensity.push({
        dayKey: cursor,
        label,
        shortLabel,
        avgIntensity: Math.round((sum / dayEntries.length) * 10) / 10,
        entryCount: dayEntries.length,
      });
    } else {
      intensity.push({
        dayKey: cursor,
        label,
        shortLabel,
        avgIntensity: 0,
        entryCount: 0,
      });
    }

    entries.push({
      dayKey: cursor,
      label,
      shortLabel,
      count: dayEntries.length,
    });

    cursor = addDaysToKey(cursor, 1);
  }

  return { intensity, entries };
}

function buildWeekSlice(
  allEntries: JournalEntry[],
  startKey: string,
  endKey: string,
): WeekSliceStats {
  const weekEntries = entriesInRange(allEntries, startKey, endKey);
  const { intensity, entries } = buildDaySeries(weekEntries, startKey, endKey);

  return {
    startDayKey: startKey,
    endDayKey: endKey,
    entryCount: weekEntries.length,
    dominantEmotions: extractEmotions(weekEntries),
    repeatedConcerns: extractConcerns(weekEntries),
    repeatedEntities: extractEntities(weekEntries),
    recurringThemes: extractThemes(weekEntries),
    avgIntensity: avgIntensity(weekEntries),
    intensityByDay: intensity,
    entryTimeline: entries,
  };
}

function buildEmotionalShift(
  thisWeek: WeekSliceStats,
  lastWeek: WeekSliceStats,
): EmotionalShift {
  const thisAvg = thisWeek.avgIntensity;
  const lastAvg = lastWeek.avgIntensity;

  if (thisAvg === null || lastAvg === null) {
    return {
      direction: "unknown",
      intensityDelta: null,
      label: "Not enough data yet",
      detail:
        "Record reflections on multiple days to compare emotional intensity week over week.",
    };
  }

  const delta = Math.round((thisAvg - lastAvg) * 10) / 10;
  const thisMood = thisWeek.dominantEmotions[0]?.label ?? null;
  const lastMood = lastWeek.dominantEmotions[0]?.label ?? null;

  let direction: EmotionalShiftDirection = "stable";
  if (Math.abs(delta) < 0.5) direction = "stable";
  else if (delta > 0) direction = "intenser";
  else direction = "calmer";

  if (thisMood && lastMood && thisMood !== lastMood && Math.abs(delta) < 1) {
    direction = "mixed";
  }

  const labels: Record<EmotionalShiftDirection, string> = {
    calmer: "Emotional intensity eased",
    intenser: "Emotional intensity rose",
    stable: "Emotional tone held steady",
    mixed: "Your emotional tone shifted",
    unknown: "Building your weekly picture",
  };

  const details: Record<EmotionalShiftDirection, string> = {
    calmer: `Average intensity moved from ${lastAvg}/10 to ${thisAvg}/10 (${delta > 0 ? "+" : ""}${delta}).`,
    intenser: `Average intensity moved from ${lastAvg}/10 to ${thisAvg}/10 (+${delta}).`,
    stable: `You hovered around ${thisAvg}/10 on average, similar to last week (${lastAvg}/10).`,
    mixed: `${lastMood} → ${thisMood} with intensity at ${thisAvg}/10 vs ${lastAvg}/10 last week.`,
    unknown: "",
  };

  return {
    direction,
    intensityDelta: delta,
    label: labels[direction],
    detail: details[direction],
  };
}

export function analyzeWeeklyIntelligence(): WeeklyIntelligenceReport {
  const endKey = todayKey();
  const thisStart = addDaysToKey(endKey, -6);
  const lastEnd = addDaysToKey(endKey, -7);
  const lastStart = addDaysToKey(endKey, -13);

  const allEntries = getEntries();
  const thisWeek = buildWeekSlice(allEntries, thisStart, endKey);
  const lastWeek = buildWeekSlice(allEntries, lastStart, lastEnd);

  const comparison: WeekComparison = {
    entryCount: {
      thisWeek: thisWeek.entryCount,
      lastWeek: lastWeek.entryCount,
    },
    avgIntensity: {
      thisWeek: thisWeek.avgIntensity,
      lastWeek: lastWeek.avgIntensity,
    },
    dominantEmotion: {
      thisWeek: thisWeek.dominantEmotions[0]?.label ?? null,
      lastWeek: lastWeek.dominantEmotions[0]?.label ?? null,
    },
    topTheme: {
      thisWeek: thisWeek.recurringThemes[0]?.label ?? null,
      lastWeek: lastWeek.recurringThemes[0]?.label ?? null,
    },
  };

  return {
    weekEndingKey: endKey,
    weekRangeLabel: formatRangeLabel(thisStart, endKey),
    previousWeekRangeLabel: formatRangeLabel(lastStart, lastEnd),
    generatedAt: new Date().toISOString(),
    thisWeek,
    lastWeek,
    comparison,
    emotionalShift: buildEmotionalShift(thisWeek, lastWeek),
    hasData: thisWeek.entryCount > 0,
  };
}

export function buildWeeklyReflectionPayload(
  report: WeeklyIntelligenceReport,
): WeeklyReflectionPayload {
  const entries = entriesInRange(
    getEntries(),
    report.thisWeek.startDayKey,
    report.thisWeek.endDayKey,
  );

  return {
    weekEndingKey: report.weekEndingKey,
    entryCount: report.thisWeek.entryCount,
    lastWeekEntryCount: report.lastWeek.entryCount,
    dominantEmotions: report.thisWeek.dominantEmotions.map((e) => e.label),
    repeatedConcerns: report.thisWeek.repeatedConcerns.slice(0, 5).map((c) => c.label),
    repeatedEntities: report.thisWeek.repeatedEntities.slice(0, 5).map((e) => e.label),
    recurringThemes: report.thisWeek.recurringThemes.slice(0, 6).map((t) => t.label),
    avgIntensityThisWeek: report.thisWeek.avgIntensity,
    avgIntensityLastWeek: report.lastWeek.avgIntensity,
    emotionalShiftLabel: report.emotionalShift.label,
    observationHighlights: entries
      .slice(0, 5)
      .map((e) => getPrimaryObservation(e.reflection))
      .filter((o): o is string => Boolean(o)),
  };
}

export function buildLocalWeeklySummary(report: WeeklyIntelligenceReport): string {
  if (!report.hasData) {
    return "Your weekly reflection will appear after you log a few voice entries this week. One minute a day is enough to see patterns emerge.";
  }

  const { thisWeek, comparison, emotionalShift } = report;
  const mood = thisWeek.dominantEmotions[0]?.label ?? "mixed";
  const theme = thisWeek.recurringThemes[0]?.label;
  const concern = thisWeek.repeatedConcerns[0]?.label;
  const entity = thisWeek.repeatedEntities[0]?.label;

  const parts = [
    `This week you recorded ${thisWeek.entryCount} reflection${thisWeek.entryCount === 1 ? "" : "s"}. Your dominant emotional tone felt ${mood}.`,
    emotionalShift.detail,
  ];

  if (theme) {
    parts.push(`Themes like “${theme}” kept showing up in what you shared.`);
  }
  if (concern) {
    parts.push(`A recurring undercurrent was around ${concern}.`);
  }
  if (entity) {
    parts.push(`${entity} appeared often in your stories.`);
  }

  if (comparison.entryCount.lastWeek > 0) {
    const diff = thisWeek.entryCount - comparison.entryCount.lastWeek;
    if (diff > 0) {
      parts.push(`You checked in ${diff} more time${diff === 1 ? "" : "s"} than last week — more chances for your own words to come back.`);
    }
  }

  return parts.join(" ");
}
