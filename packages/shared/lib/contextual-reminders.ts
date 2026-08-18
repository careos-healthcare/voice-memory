import { daysBetweenKeys, todayKey, toDayKey } from "@/lib/dates";
import { getHabitStats } from "@/lib/habit-storage";
import {
  DEFAULT_REMINDER_PREFERENCES,
  getReminderPreferences,
  type ReminderPreferences,
} from "@/lib/reminder-preferences";
import { getEntries } from "@/lib/storage";
import { analyzeWeeklyIntelligence } from "@/lib/weekly-intelligence";

export type ReminderKind =
  | "daily"
  | "stressful"
  | "weekly"
  | "inactive"
  | "usual_time";

export interface ContextualReminder {
  id: string;
  kind: ReminderKind;
  title: string;
  message: string;
  href: string;
  cta: string;
}

export interface ReminderCopyExample {
  kind: ReminderKind;
  message: string;
  whenShown: string;
}

export const REMINDER_COPY_EXAMPLES: ReminderCopyExample[] = [
  {
    kind: "stressful",
    message: "Your words from a heavy moment are still here",
    whenShown: "After a stressful entry (intensity 7+) with no follow-up reflection",
  },
  {
    kind: "weekly",
    message: "Your week is ready to look back on",
    whenShown: "When you have entries this week and weekly review is enabled",
  },
  {
    kind: "usual_time",
    message: "You usually reflect around this time",
    whenShown: "Near your preferred daily reflection hour, if you have not reflected today",
  },
  {
    kind: "daily",
    message: "When you're ready, a short voice note can help close the day",
    whenShown: "Daily reflection preference on, no entry yet today",
  },
  {
    kind: "inactive",
    message: "Your words are still here when you are ready",
    whenShown: "No reflection for 3+ days with inactivity reminders enabled",
  },
];

const STRESS_INTENSITY_THRESHOLD = 7;

function formatHour(hour: number): string {
  const h = hour % 12 || 12;
  const suffix = hour < 12 ? "AM" : "PM";
  return `${h}:00 ${suffix}`;
}

function isNearPreferredHour(preferredHour: number): boolean {
  const now = new Date();
  const current = now.getHours();
  const diff = Math.abs(current - preferredHour);
  return diff <= 1 || diff >= 23;
}

function latestStressfulEntry() {
  const entries = getEntries();
  return entries.find(
    (e) => e.reflection.emotionalIntensity >= STRESS_INTENSITY_THRESHOLD,
  );
}

export function evaluateContextualReminders(
  prefs: ReminderPreferences = getReminderPreferences(),
): ContextualReminder[] {
  const reminders: ContextualReminder[] = [];
  const entries = getEntries();
  const habit = getHabitStats();
  const today = todayKey();

  if (entries.length === 0) {
    return [];
  }

  if (prefs.dailyReflection && !habit.reflectedToday) {
    if (isNearPreferredHour(prefs.preferredReflectionHour)) {
      reminders.push({
        id: "usual_time",
        kind: "usual_time",
        title: "Your usual time",
        message: "You usually reflect around this time",
        href: "/",
        cta: "Record reflection",
      });
    } else {
      reminders.push({
        id: "daily",
        kind: "daily",
        title: "Daily reflection",
        message: "When you're ready, a short voice note can help close the day",
        href: "/",
        cta: "Record reflection",
      });
    }
  }

  if (prefs.afterStressfulEntry) {
    const stressful = latestStressfulEntry();
    if (stressful) {
      const stressDay = toDayKey(stressful.createdAt);
      const daysSince = daysBetweenKeys(stressDay, today);
      const stressTime = new Date(stressful.createdAt).getTime();
      const reflectedSince = entries.some(
        (e) => new Date(e.createdAt).getTime() > stressTime,
      );

      if (daysSince <= 7 && !reflectedSince && !habit.reflectedToday) {
        reminders.push({
          id: "stressful",
          kind: "stressful",
          title: "After a heavy moment",
          message: "Your words from a heavy moment are still here",
          href: "/",
          cta: "View reflections",
        });
      }
    }
  }

  if (prefs.weeklyReview) {
    const weekly = analyzeWeeklyIntelligence();
    if (weekly.hasData && weekly.thisWeek.entryCount > 0) {
      const dow = new Date().getDay();
      const isReviewWindow = dow === 0 || dow === 5 || dow === 6;
      if (isReviewWindow || weekly.thisWeek.entryCount >= 3) {
        reminders.push({
          id: "weekly",
          kind: "weekly",
          title: "Weekly review",
          message: "Your week is ready to look back on",
          href: "/weekly",
          cta: "View your week",
        });
      }
    }
  }

  if (prefs.inactiveThreeDays && habit.lastReflectionDate) {
    const inactiveDays = daysBetweenKeys(habit.lastReflectionDate, today);
    if (inactiveDays >= 3 && !habit.reflectedToday) {
      reminders.push({
        id: "inactive",
        kind: "inactive",
        title: "Gentle check-in",
        message: "Your words are still here when you are ready",
        href: "/",
        cta: "View reflections",
      });
    }
  }

  const seen = new Set<string>();
  return reminders.filter((r) => {
    if (seen.has(r.kind)) return false;
    seen.add(r.kind);
    return true;
  });
}

export function getPreferredHourLabel(
  hour: number = getReminderPreferences().preferredReflectionHour,
): string {
  return formatHour(hour);
}

export { DEFAULT_REMINDER_PREFERENCES };
