import { daysBetweenKeys, todayKey, toDayKey } from "@/lib/dates";
import { countFeedbackByRating, readAllFeedback } from "@/lib/feedback-storage";
import { getHabitStats } from "@/lib/habit-storage";
import {
  countLocalEvents,
  LAUNCH_EVENTS,
  readLocalEvents,
} from "@/lib/local-analytics";
import { getStoredEntryCount } from "@/lib/storage";
import { getUpgradeClickEvents } from "@/lib/subscription";

export interface RetentionDashboard {
  totalReflections: number;
  streak: number;
  daysActive: number;
  avgReflectionsPerWeek: number;
  weeklyReturnEstimate: number;
  firstReflectionAt: string | null;
  lastReflectionAt: string | null;
  featureUsage: {
    onboardingCompleted: number;
    firstReflectionCreated: number;
    secondReflectionCreated: number;
    weeklyPageOpened: number;
    memoryPageOpened: number;
    exportUsed: number;
    shareCardCopied: number;
    memoryMomentCopied: number;
    upgradeClicked: number;
    feedbackSubmitted: number;
  };
  feedback: { up: number; down: number; total: number };
  upgradeClicks: number;
  totalLocalEvents: number;
}

function uniqueActiveDaysFromEntries(): string[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem("voicememory_entries");
    if (!raw) return [];
    const entries = JSON.parse(raw) as { createdAt: string }[];
    return [...new Set(entries.map((e) => toDayKey(e.createdAt)))].sort();
  } catch {
    return [];
  }
}

function estimateWeeklyReturn(daysActive: number, weeklyOpens: number): number {
  if (daysActive === 0) return 0;
  const weeksSinceFirst = Math.max(1, daysActive / 7);
  const openRate = weeklyOpens / weeksSinceFirst;
  return Math.min(100, Math.round(openRate * 100));
}

export function buildRetentionDashboard(): RetentionDashboard {
  const totalReflections = getStoredEntryCount();
  const habit = getHabitStats();
  const dayKeys = uniqueActiveDaysFromEntries();
  const daysActive = dayKeys.length;

  const firstDay = dayKeys[0] ?? null;
  const lastDay = dayKeys[dayKeys.length - 1] ?? null;

  let avgReflectionsPerWeek = 0;
  if (firstDay && lastDay && totalReflections > 0) {
    const spanDays = Math.max(1, daysBetweenKeys(firstDay, lastDay) + 1);
    const weeks = spanDays / 7;
    avgReflectionsPerWeek = Math.round((totalReflections / weeks) * 10) / 10;
  }

  const weeklyPageOpened = countLocalEvents(LAUNCH_EVENTS.weeklyPageOpened);
  const weeklyReturnEstimate = estimateWeeklyReturn(daysActive, weeklyPageOpened);

  const upgradeClicksFromEvents = countLocalEvents(LAUNCH_EVENTS.upgradeClicked);
  const upgradeClicksFromStore = getUpgradeClickEvents().length;

  const feedbackCounts = countFeedbackByRating();

  return {
    totalReflections,
    streak: habit.streak,
    daysActive,
    avgReflectionsPerWeek,
    weeklyReturnEstimate,
    firstReflectionAt: firstDay,
    lastReflectionAt: lastDay,
    featureUsage: {
      onboardingCompleted: countLocalEvents(LAUNCH_EVENTS.onboardingCompleted),
      firstReflectionCreated: countLocalEvents(LAUNCH_EVENTS.firstReflectionCreated),
      secondReflectionCreated: countLocalEvents(LAUNCH_EVENTS.secondReflectionCreated),
      weeklyPageOpened,
      memoryPageOpened: countLocalEvents(LAUNCH_EVENTS.memoryPageOpened),
      exportUsed: countLocalEvents(LAUNCH_EVENTS.exportUsed),
      shareCardCopied: countLocalEvents(LAUNCH_EVENTS.shareCardCopied),
      memoryMomentCopied: countLocalEvents(LAUNCH_EVENTS.memoryMomentCopied),
      upgradeClicked: Math.max(upgradeClicksFromEvents, upgradeClicksFromStore),
      feedbackSubmitted: countLocalEvents(LAUNCH_EVENTS.feedbackSubmitted),
    },
    feedback: {
      ...feedbackCounts,
      total: readAllFeedback().length,
    },
    upgradeClicks: Math.max(upgradeClicksFromEvents, upgradeClicksFromStore),
    totalLocalEvents: readLocalEvents().length,
  };
}
