import { getEntries } from "@/lib/storage";
import { addDaysToKey, daysBetweenKeys, startOfWeekKey, todayKey, toDayKey } from "@/lib/dates";
import type { JournalEntry } from "@/types/journal";

const HABIT_KEY = "voicememory_habit";

export interface HabitState {
  reflectionDayKeys: string[];
}

export interface DayComparison {
  entryCount: number;
  avgIntensity: number | null;
  dominantMood: string | null;
}

export interface WeeklyRecap {
  entryCount: number;
  dominantMood: string | null;
  topTheme: string | null;
  avgIntensity: number | null;
  streakAtWeekEnd: number;
}

export interface HabitStats {
  streak: number;
  /** User-facing consecutive reflection day count (same as streak). */
  consecutiveReflectionDays: number;
  lastReflectionDate: string | null;
  reflectedToday: boolean;
  today: DayComparison;
  yesterday: DayComparison;
  weeklyRecap: WeeklyRecap;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function loadHabitState(): HabitState {
  if (!isBrowser()) return { reflectionDayKeys: [] };

  try {
    const raw = localStorage.getItem(HABIT_KEY);
    if (!raw) return { reflectionDayKeys: [] };
    const parsed = JSON.parse(raw) as HabitState;
    return {
      reflectionDayKeys: Array.isArray(parsed.reflectionDayKeys)
        ? [...new Set(parsed.reflectionDayKeys)].sort()
        : [],
    };
  } catch {
    return { reflectionDayKeys: [] };
  }
}

function saveHabitState(state: HabitState): void {
  if (!isBrowser()) return;
  localStorage.setItem(HABIT_KEY, JSON.stringify(state));
}

/** Sync habit days from journal entries (source of truth). */
export function syncHabitFromEntries(): void {
  const dayKeys = [
    ...new Set(getEntries().map((e) => toDayKey(e.createdAt))),
  ].sort();
  saveHabitState({ reflectionDayKeys: dayKeys });
}

export function clearHabitState(): void {
  saveHabitState({ reflectionDayKeys: [] });
}

export function recordReflectionDay(iso: string): void {
  const key = toDayKey(iso);
  const state = loadHabitState();
  if (!state.reflectionDayKeys.includes(key)) {
    state.reflectionDayKeys.push(key);
    state.reflectionDayKeys.sort();
    saveHabitState(state);
  }
}

function computeStreak(dayKeys: string[]): number {
  if (dayKeys.length === 0) return 0;

  const set = new Set(dayKeys);
  const today = todayKey();
  const yesterday = addDaysToKey(today, -1);

  let anchor = today;
  if (!set.has(today)) {
    if (!set.has(yesterday)) return 0;
    anchor = yesterday;
  }

  let streak = 0;
  let cursor = anchor;
  while (set.has(cursor)) {
    streak += 1;
    cursor = addDaysToKey(cursor, -1);
  }
  return streak;
}

function entriesForDay(entries: JournalEntry[], dayKey: string): JournalEntry[] {
  return entries.filter((e) => toDayKey(e.createdAt) === dayKey);
}

function summarizeDay(entries: JournalEntry[]): DayComparison {
  if (entries.length === 0) {
    return { entryCount: 0, avgIntensity: null, dominantMood: null };
  }

  const moodCounts = new Map<string, number>();
  let intensitySum = 0;

  for (const entry of entries) {
    const mood = entry.reflection.mood.toLowerCase();
    moodCounts.set(mood, (moodCounts.get(mood) ?? 0) + 1);
    intensitySum += entry.reflection.emotionalIntensity;
  }

  const dominantMood = [...moodCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

  return {
    entryCount: entries.length,
    avgIntensity: Math.round((intensitySum / entries.length) * 10) / 10,
    dominantMood,
  };
}

function buildWeeklyRecap(entries: JournalEntry[], streak: number): WeeklyRecap {
  const weekStart = startOfWeekKey();
  const weekEntries = entries.filter((e) => toDayKey(e.createdAt) >= weekStart);

  if (weekEntries.length === 0) {
    return {
      entryCount: 0,
      dominantMood: null,
      topTheme: null,
      avgIntensity: null,
      streakAtWeekEnd: streak,
    };
  }

  const moodCounts = new Map<string, number>();
  const themeCounts = new Map<string, number>();
  let intensitySum = 0;

  for (const entry of weekEntries) {
    moodCounts.set(
      entry.reflection.mood.toLowerCase(),
      (moodCounts.get(entry.reflection.mood.toLowerCase()) ?? 0) + 1,
    );
    intensitySum += entry.reflection.emotionalIntensity;
    for (const theme of entry.reflection.recurringThemes) {
      const normalized = theme.trim().toLowerCase();
      if (normalized) {
        themeCounts.set(normalized, (themeCounts.get(normalized) ?? 0) + 1);
      }
    }
  }

  const dominantMood =
    [...moodCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;
  const topTheme =
    [...themeCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

  return {
    entryCount: weekEntries.length,
    dominantMood,
    topTheme,
    avgIntensity: Math.round((intensitySum / weekEntries.length) * 10) / 10,
    streakAtWeekEnd: streak,
  };
}

export function getHabitStats(): HabitStats {
  syncHabitFromEntries();
  const entries = getEntries();
  const dayKeys = [...new Set(entries.map((e) => toDayKey(e.createdAt)))].sort();
  const streak = computeStreak(dayKeys);
  const lastReflectionDate = dayKeys.length > 0 ? dayKeys[dayKeys.length - 1] : null;
  const today = todayKey();
  const yesterday = addDaysToKey(today, -1);

  return {
    streak,
    consecutiveReflectionDays: streak,
    lastReflectionDate,
    reflectedToday: dayKeys.includes(today),
    today: summarizeDay(entriesForDay(entries, today)),
    yesterday: summarizeDay(entriesForDay(entries, yesterday)),
    weeklyRecap: buildWeeklyRecap(entries, streak),
  };
}

export function formatLastReflectionLabel(isoDayKey: string | null): string {
  if (!isoDayKey) return "Never";

  const today = todayKey();
  const diff = daysBetweenKeys(isoDayKey, today);

  if (diff === 0) return "Today";
  if (diff === 1) return "Yesterday";
  if (diff < 7) return `${diff} days ago`;

  const [y, m, d] = isoDayKey.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
  }).format(new Date(y, m - 1, d));
}
