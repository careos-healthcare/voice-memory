const PREFERENCES_KEY = "voicememory_reminder_preferences";

export interface ReminderPreferences {
  dailyReflection: boolean;
  afterStressfulEntry: boolean;
  weeklyReview: boolean;
  inactiveThreeDays: boolean;
  /** 0–23 local hour for “usually reflect around this time” copy. */
  preferredReflectionHour: number;
}

export const DEFAULT_REMINDER_PREFERENCES: ReminderPreferences = {
  dailyReflection: false,
  afterStressfulEntry: false,
  weeklyReview: false,
  inactiveThreeDays: false,
  preferredReflectionHour: 20,
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getReminderPreferences(): ReminderPreferences {
  if (!isBrowser()) return { ...DEFAULT_REMINDER_PREFERENCES };

  try {
    const raw = localStorage.getItem(PREFERENCES_KEY);
    if (!raw) return { ...DEFAULT_REMINDER_PREFERENCES };

    const parsed = JSON.parse(raw) as Partial<ReminderPreferences>;
    const hour = Number(parsed.preferredReflectionHour);

    return {
      dailyReflection:
        parsed.dailyReflection ?? DEFAULT_REMINDER_PREFERENCES.dailyReflection,
      afterStressfulEntry:
        parsed.afterStressfulEntry ??
        DEFAULT_REMINDER_PREFERENCES.afterStressfulEntry,
      weeklyReview:
        parsed.weeklyReview ?? DEFAULT_REMINDER_PREFERENCES.weeklyReview,
      inactiveThreeDays:
        parsed.inactiveThreeDays ??
        DEFAULT_REMINDER_PREFERENCES.inactiveThreeDays,
      preferredReflectionHour:
        Number.isFinite(hour) && hour >= 0 && hour <= 23
          ? Math.round(hour)
          : DEFAULT_REMINDER_PREFERENCES.preferredReflectionHour,
    };
  } catch {
    return { ...DEFAULT_REMINDER_PREFERENCES };
  }
}

export function saveReminderPreferences(prefs: ReminderPreferences): void {
  if (!isBrowser()) return;
  localStorage.setItem(PREFERENCES_KEY, JSON.stringify(prefs));
}

export function clearReminderPreferences(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(PREFERENCES_KEY);
}
