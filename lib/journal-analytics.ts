import { addDaysToKey, todayKey, toDayKey } from "@/lib/dates";
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

export interface PositiveSignalPoint {
  date: string;
  label: string;
  signal: string;
  mood: string;
}

export interface WeeklyMention {
  label: string;
  count: number;
}

export interface MemoryInsights {
  totalEntries: number;
  dominantMoods: MoodCount[];
  recurringThemes: ThemeCount[];
  intensityTrend: IntensityPoint[];
  mostMentionedConcern: string | null;
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

function tokenizeConcern(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^\w\s'-]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 3);
}

function concernPhrase(entries: JournalEntry[]): string | null {
  const phraseCounts = new Map<string, number>();

  for (const entry of entries) {
    const concern = entry.reflection.hiddenConcern.trim();
    if (!concern) continue;

    const normalized = concern.toLowerCase();
    phraseCounts.set(normalized, (phraseCounts.get(normalized) ?? 0) + 1);

    for (const token of tokenizeConcern(concern)) {
      phraseCounts.set(token, (phraseCounts.get(token) ?? 0) + 1);
    }
  }

  const top = topFromMap(phraseCounts, 1)[0];
  if (!top) return null;

  if (top.key.length > 40) {
    return top.key.slice(0, 40) + "…";
  }
  return top.key;
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

    const concernTokens = tokenizeConcern(entry.reflection.hiddenConcern);
    for (const token of concernTokens.slice(0, 3)) {
      counts.set(token, (counts.get(token) ?? 0) + 1);
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
      mostMentionedConcern: null,
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

  const positiveSignalsOverTime: PositiveSignalPoint[] = [...entries]
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
    .slice(-8)
    .map((entry) => ({
      date: entry.createdAt,
      label: new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "numeric",
      }).format(new Date(entry.createdAt)),
      signal: entry.reflection.positiveSignal,
      mood: entry.reflection.mood,
    }));

  return {
    totalEntries: entries.length,
    dominantMoods,
    recurringThemes,
    intensityTrend: buildIntensityTrend(entries),
    mostMentionedConcern: concernPhrase(entries),
    positiveSignalsOverTime,
    weeklyMentions: buildWeeklyMentions(entries),
    hasData: true,
  };
}
