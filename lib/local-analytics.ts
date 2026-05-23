export type LocalAnalyticsEvent = {
  name: string;
  at: string;
  meta?: Record<string, string>;
};

export const LAUNCH_EVENTS = {
  onboardingCompleted: "onboarding_completed",
  firstReflectionCreated: "first_reflection_created",
  secondReflectionCreated: "second_reflection_created",
  weeklyPageOpened: "weekly_page_opened",
  memoryPageOpened: "memory_page_opened",
  exportUsed: "export_used",
  shareCardCopied: "share_card_copied",
  upgradeClicked: "upgrade_clicked",
  feedbackSubmitted: "feedback_submitted",
  demoModeEntered: "demo_mode_entered",
  demoModeExited: "demo_mode_exited",
} as const;

export type LaunchEventName = (typeof LAUNCH_EVENTS)[keyof typeof LAUNCH_EVENTS];

const EVENTS_KEY = "voicememory_local_events";
const MAX_EVENTS = 500;

export function trackLocalEvent(
  name: string,
  meta?: Record<string, string>,
): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem(EVENTS_KEY);
    const events: LocalAnalyticsEvent[] = raw ? (JSON.parse(raw) as LocalAnalyticsEvent[]) : [];
    events.push({
      name,
      at: new Date().toISOString(),
      meta,
    });
    localStorage.setItem(
      EVENTS_KEY,
      JSON.stringify(events.slice(-MAX_EVENTS)),
    );
  } catch {
    // Local-only telemetry — never block UX.
  }
}

export function trackLaunchEvent(
  name: LaunchEventName,
  meta?: Record<string, string>,
): void {
  trackLocalEvent(name, meta);
}

export function readLocalEvents(): LocalAnalyticsEvent[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(EVENTS_KEY);
    return raw ? (JSON.parse(raw) as LocalAnalyticsEvent[]) : [];
  } catch {
    return [];
  }
}

export function countLocalEvents(name: string): number {
  return readLocalEvents().filter((event) => event.name === name).length;
}

export function hasLocalEvent(name: string): boolean {
  return countLocalEvents(name) > 0;
}

export function clearLocalEvents(): void {
  if (typeof window === "undefined") return;
  localStorage.removeItem(EVENTS_KEY);
}

/** Fire first/second reflection milestones once per device. */
export function trackReflectionMilestones(totalAfterSave: number): void {
  if (totalAfterSave >= 1 && !hasLocalEvent(LAUNCH_EVENTS.firstReflectionCreated)) {
    trackLaunchEvent(LAUNCH_EVENTS.firstReflectionCreated);
  }
  if (totalAfterSave >= 2 && !hasLocalEvent(LAUNCH_EVENTS.secondReflectionCreated)) {
    trackLaunchEvent(LAUNCH_EVENTS.secondReflectionCreated);
  }
}
