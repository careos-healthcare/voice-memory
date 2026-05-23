import { startOfWeekKey, todayKey, toDayKey } from "@/lib/dates";
import { getHabitStats, type HabitStats } from "@/lib/habit-storage";
import { getEntries } from "@/lib/storage";
import type { ReflectionGoal, ReflectionGoalOption } from "@/types/reflection-goal";

const GOAL_KEY = "voicememory_reflection_goal";
const HINT_KEY = "voicememory_reflection_goal_hint";

export const REFLECTION_GOAL_OPTIONS: ReflectionGoalOption[] = [
  {
    value: "off",
    label: "No goal",
    description: "Record when you want — no nudges about frequency.",
  },
  {
    value: "when_ready",
    label: "When it feels right",
    description: "A quiet intention to return, without counting days or entries.",
  },
  {
    value: "few_per_week",
    label: "A few times a week",
    description: "A gentle aim for two or three reflections across the week.",
  },
  {
    value: "most_days",
    label: "Most days",
    description: "A soft rhythm of checking in — not a streak to keep.",
  },
];

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getReflectionGoal(): ReflectionGoal {
  if (!isBrowser()) return "off";

  try {
    const raw = localStorage.getItem(GOAL_KEY);
    if (!raw) return "off";
    const value = raw as ReflectionGoal;
    return REFLECTION_GOAL_OPTIONS.some((option) => option.value === value) ? value : "off";
  } catch {
    return "off";
  }
}

export function setReflectionGoal(goal: ReflectionGoal): void {
  if (!isBrowser()) return;
  localStorage.setItem(GOAL_KEY, goal);
  window.dispatchEvent(new CustomEvent("voicememory:reflection-goal"));
}

export function clearReflectionGoal(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(GOAL_KEY);
  localStorage.removeItem(HINT_KEY);
}

function entriesThisWeek(): number {
  const weekStart = startOfWeekKey(todayKey());
  return getEntries().filter((entry) => toDayKey(entry.createdAt) >= weekStart).length;
}

function readHintDay(): string | null {
  if (!isBrowser()) return null;
  try {
    return localStorage.getItem(HINT_KEY);
  } catch {
    return null;
  }
}

function markHintShown(): void {
  if (!isBrowser()) return;
  localStorage.setItem(HINT_KEY, todayKey());
}

export function reflectionGoalHint(
  goal: ReflectionGoal = getReflectionGoal(),
  stats: HabitStats = getHabitStats(),
): string | null {
  if (goal === "off" || goal === "when_ready") return null;
  if (readHintDay() === todayKey()) return null;

  if (goal === "few_per_week") {
    if (entriesThisWeek() >= 2 || stats.reflectedToday) return null;
    return "Your gentle goal is a few reflections this week. One note is enough when you need it.";
  }

  if (goal === "most_days") {
    if (stats.reflectedToday) return null;
    if (!stats.lastReflectionDate) {
      return "Your gentle goal is most days — return when a minute feels available.";
    }
    return "Your gentle goal is most days. There is no streak to maintain — just return when you can.";
  }

  return null;
}

export function recordReflectionGoalHintShown(): void {
  markHintShown();
}
