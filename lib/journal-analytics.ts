import { addDaysToKey, todayKey, toDayKey } from "@/lib/dates";
import { getPrimaryObservation } from "@/lib/observation-language";
import { getEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface MoodCount {
  mood: string;
  count: number;
  share: number;
}

export interface ThemeCount {
  theme: string;
  count: number;
}

export interface IntensityPoint {
  dayKey: string;
  label: string;
  avgIntensity: number;
  entryCount: number;
}

export interface ObservationPoint {
  date: string;
  label: string;
  observation: string;
  mood: string;
}

export interface WeeklyMention {
  label: string;
  count: number;
}

export interface PositiveSignalPoint {
  dayKey: string;
  label: string;
  signal: string;
  mood: string;
}

export interface MemoryInsights {
  totalEntries: number;
  dominantMoods: MoodCount[];
  recurringThemes: ThemeCount[];
  intensityTrend: IntensityPoint[];
  mostRepeatedPattern: string | null;
  mostMentionedConcern: string | null;
  observationsOverTime: ObservationPoint[];
  positiveSignalsOverTime: PositiveSignalPoint[];
  weeklyMentions: WeeklyMention[];
  hasData: boolean;
}

function countMap(items: string[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const item of items) {
    const key = item.trim().toLowerCase();
    if (!key) continue;
    map.set(key, (map.get(key) ?? 0) + 1);
  }
  return map;
}

function topFromMap(map: Map<string, number>, limit = 5): { key: string; count: number }[] {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([key, count]) => ({ key, count }));
}

function mostRepeatedPattern(entries: JournalEntry[]): string | null {
  const themeMap = countMap(entries.flatMap((e) => e.reflection.recurringThemes));
  const topTheme = topFromMap(themeMap, 1)[0];
  if (topTheme && topTheme.count >= 2) {
    return `"${topTheme.key}" across ${topTheme.count} entries`;
  }

  const phraseCounts = new Map<string, number>();
  for (const entry of entries) {
    const obs = entry.reflection.patternObservations?.[0];
    if (obs) {
      const key = obs.slice(0, 60).toLowerCase();
      phraseCounts.set(key, (phraseCounts.get(key) ?? 0) + 1);
    }
  }

  const topPhrase = topFromMap(phraseCounts, 1)[0];
  if (topPhrase && topPhrase.count >= 2) {
    return topPhrase.key.slice(0, 80);
  }

  return topTheme ? `"${topTheme.key}"` : null;
}

function buildIntensityTrend(entries: JournalEntry[], days = 14): IntensityPoint[] {
  const today = todayKey();
  const points: IntensityPoint[] = [];

  for (let i = days - 1; i >= 0; i -= 1) {
    const dayKey = addDaysToKey(today, -i);
    const dayEntries = entries.filter((e) => toDayKey(e.createdAt) === dayKey);

    const [y, m, d] = dayKey.split("-").map(Number);
    const label = new Intl.DateTimeFormat("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
    }).format(new Date(y, m - 1, d));

    if (dayEntries.length === 0) {
      points.push({
        dayKey,
        label,
        avgIntensity: 0,
        entryCount: 0,
      });
      continue;
    }

    const sum = dayEntries.reduce(
      (acc, e) => acc + e.reflection.emotionalIntensity,
      0,
    );

    points.push({
      dayKey,
      label,
      avgIntensity: Math.round((sum / dayEntries.length) * 10) / 10,
      entryCount: dayEntries.length,
    });
  }

  return points;
}

function buildMostMentionedConcern(entries: JournalEntry[]): string | null {
  const counts = new Map<string, number>();

  for (const entry of entries) {
    const candidates = [
      entry.reflection.hiddenConcern,
      entry.reflection.avoidedOrVagueArea,
      entry.reflection.repeatedSignal,
      entry.reflection.tensionOrContradiction,
    ];

    for (const raw of candidates) {
      const text = raw?.trim();
      if (!text || text.length < 4) continue;
      const key = text.slice(0, 80).toLowerCase();
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }

  const top = topFromMap(counts, 1)[0];
  if (!top) return null;
  if (top.count >= 2) {
    return `"${top.key}" mentioned ${top.count} times`;
  }
  return top.key.length > 60 ? `${top.key.slice(0, 60)}…` : top.key;
}

function buildPositiveSignalsOverTime(entries: JournalEntry[]): PositiveSignalPoint[] {
  return [...entries]
    .filter(
      (e) =>
        e.reflection.positiveSignal.trim().length > 0 ||
        (e.reflection.concreteObservation?.trim() &&
          e.reflection.emotionalIntensity <= 5),
    )
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
    .slice(-8)
    .map((entry) => {
      const signal =
        entry.reflection.positiveSignal.trim() ||
        entry.reflection.concreteObservation?.trim() ||
        entry.reflection.mood;

      const [y, m, d] = toDayKey(entry.createdAt).split("-").map(Number);
      const label = new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "numeric",
      }).format(new Date(y, m - 1, d));

      return {
        dayKey: toDayKey(entry.createdAt),
        label,
        signal: signal.slice(0, 120),
        mood: entry.reflection.mood,
      };
    });
}

function buildWeeklyMentions(entries: JournalEntry[]): WeeklyMention[] {
  const weekAgo = addDaysToKey(todayKey(), -6);
  const recent = entries.filter((e) => toDayKey(e.createdAt) >= weekAgo);

  const counts = new Map<string, number>();

  for (const entry of recent) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.trim();
      if (!key) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }

  return topFromMap(counts, 5).map(({ key, count }) => ({
    label: key,
    count,
  }));
}

export function analyzeJournalEntries(): MemoryInsights {
  const entries = getEntries();

  if (entries.length === 0) {
    return {
      totalEntries: 0,
      dominantMoods: [],
      recurringThemes: [],
      intensityTrend: buildIntensityTrend([]),
      mostRepeatedPattern: null,
      mostMentionedConcern: null,
      observationsOverTime: [],
      positiveSignalsOverTime: [],
      weeklyMentions: [],
      hasData: false,
    };
  }

  const moods = countMap(entries.map((e) => e.reflection.mood));
  const dominantMoods: MoodCount[] = topFromMap(moods, 5).map(({ key, count }) => ({
    mood: key,
    count,
    share: Math.round((count / entries.length) * 100),
  }));

  const allThemes = entries.flatMap((e) => e.reflection.recurringThemes);
  const themeMap = countMap(allThemes);
  const recurringThemes: ThemeCount[] = topFromMap(themeMap, 8).map(({ key, count }) => ({
    theme: key,
    count,
  }));

  const observationsOverTime: ObservationPoint[] = [...entries]
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
    .slice(-8)
    .map((entry) => ({
      date: entry.createdAt,
      label: new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "numeric",
      }).format(new Date(entry.createdAt)),
      observation: getPrimaryObservation(entry.reflection) ?? entry.reflection.mood,
      mood: entry.reflection.mood,
    }));

  return {
    totalEntries: entries.length,
    dominantMoods,
    recurringThemes,
    intensityTrend: buildIntensityTrend(entries),
    mostRepeatedPattern: mostRepeatedPattern(entries),
    mostMentionedConcern: buildMostMentionedConcern(entries),
    observationsOverTime,
    positiveSignalsOverTime: buildPositiveSignalsOverTime(entries),
    weeklyMentions: buildWeeklyMentions(entries),
    hasData: true,
  };
}
