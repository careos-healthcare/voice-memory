import { getLightweightLimits } from "@/lib/performance/lightweight-mode";

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
  memoryMomentCopied: "memory_moment_copied",
  upgradeClicked: "upgrade_clicked",
  feedbackSubmitted: "feedback_submitted",
  demoModeEntered: "demo_mode_entered",
  demoModeExited: "demo_mode_exited",
} as const;

/** Retention layer — local-only telemetry. */
export const RETENTION_EVENTS = {
  entryRecorded: "entry_recorded",
  insightViewed: "insight_viewed",
  searchPerformed: "search_performed",
  audioPlayed: "audio_played",
  pricingViewed: "pricing_viewed",
} as const;

export type RetentionEventName =
  (typeof RETENTION_EVENTS)[keyof typeof RETENTION_EVENTS];

export const PHOTO_EVENTS = {
  dragAttached: "photo_drag_attached",
  pasteAttached: "photo_paste_attached",
  replaced: "photo_replaced",
  entryRevisited: "photo_entry_revisited",
  exported: "photo_exported",
  restoreChecked: "photo_restore_checked",
} as const;

export type PhotoEventName = (typeof PHOTO_EVENTS)[keyof typeof PHOTO_EVENTS];

export type LaunchEventName = (typeof LAUNCH_EVENTS)[keyof typeof LAUNCH_EVENTS];

const EVENTS_KEY = "voicememory_local_events";
const DEDUPE_WINDOW_MS = 2000;
const FLUSH_DEBOUNCE_MS = 400;

let queue: LocalAnalyticsEvent[] = [];
let knownNames = new Set<string>();
let eventsSnapshot: LocalAnalyticsEvent[] | null = null;
let flushTimer: ReturnType<typeof setTimeout> | null = null;
let flushing = false;
let hydrated = false;

function maxEvents(): number {
  return getLightweightLimits().maxAnalyticsEvents;
}

function metaKey(meta?: Record<string, string>): string {
  if (!meta) return "";
  return Object.keys(meta)
    .sort()
    .map((key) => `${key}=${meta[key]}`)
    .join("&");
}

function dedupeKey(name: string, meta?: Record<string, string>): string {
  return `${name}|${metaKey(meta)}`;
}

function hydrateFromStorage(): void {
  if (hydrated || typeof window === "undefined") return;
  hydrated = true;
  try {
    const raw = localStorage.getItem(EVENTS_KEY);
    const parsed = raw ? (JSON.parse(raw) as LocalAnalyticsEvent[]) : [];
    eventsSnapshot = Array.isArray(parsed) ? parsed.slice(-maxEvents()) : [];
    knownNames = new Set(eventsSnapshot.map((event) => event.name));
  } catch {
    eventsSnapshot = [];
    knownNames = new Set();
  }
}

function scheduleFlush(): void {
  if (typeof window === "undefined") return;
  if (flushTimer) return;
  flushTimer = setTimeout(() => {
    flushTimer = null;
    flushAnalyticsQueue();
  }, FLUSH_DEBOUNCE_MS);
}

function flushAnalyticsQueue(): void {
  if (typeof window === "undefined" || flushing || queue.length === 0) return;
  flushing = true;
  try {
    hydrateFromStorage();
    const merged = [...(eventsSnapshot ?? []), ...queue];
    const trimmed = merged.slice(-maxEvents());
    localStorage.setItem(EVENTS_KEY, JSON.stringify(trimmed));
    eventsSnapshot = trimmed;
    for (const event of trimmed) {
      knownNames.add(event.name);
    }
    queue = [];
  } catch {
    // Local-only telemetry — never block UX.
  } finally {
    flushing = false;
  }
}

export function trackLocalEvent(
  name: string,
  meta?: Record<string, string>,
): void {
  if (typeof window === "undefined" || flushing) return;

  const now = Date.now();
  const last = queue[queue.length - 1];
  if (
    last &&
    dedupeKey(last.name, last.meta) === dedupeKey(name, meta) &&
    now - new Date(last.at).getTime() < DEDUPE_WINDOW_MS
  ) {
    return;
  }

  queue.push({
    name,
    at: new Date().toISOString(),
    meta,
  });

  if (queue.length > maxEvents()) {
    queue = queue.slice(-maxEvents());
  }

  knownNames.add(name);
  scheduleFlush();
}

export function trackLaunchEvent(
  name: LaunchEventName,
  meta?: Record<string, string>,
): void {
  trackLocalEvent(name, meta);
}

export function trackRetentionEvent(
  name: RetentionEventName,
  meta?: Record<string, string>,
): void {
  trackLocalEvent(name, meta);
}

export function trackPhotoEvent(
  name: PhotoEventName,
  meta?: Record<string, string>,
): void {
  trackLocalEvent(name, meta);
}

export function readLocalEvents(): LocalAnalyticsEvent[] {
  if (typeof window === "undefined") return [];
  hydrateFromStorage();
  if (queue.length === 0) {
    return eventsSnapshot ?? [];
  }
  return [...(eventsSnapshot ?? []), ...queue].slice(-maxEvents());
}

export function getAnalyticsQueueSize(): number {
  return queue.length;
}

export function countLocalEvents(name: string): number {
  hydrateFromStorage();
  if (knownNames.has(name) && queue.length === 0) {
    return (eventsSnapshot ?? []).filter((event) => event.name === name).length;
  }
  return readLocalEvents().filter((event) => event.name === name).length;
}

export function hasLocalEvent(name: string): boolean {
  hydrateFromStorage();
  if (knownNames.has(name)) return true;
  return queue.some((event) => event.name === name);
}

export function clearLocalEvents(): void {
  if (typeof window === "undefined") return;
  queue = [];
  knownNames = new Set();
  eventsSnapshot = [];
  hydrated = true;
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
  void import("@/lib/retention/first-week-funnel").then((mod) => {
    mod.observeFunnelReflectionSaved(totalAfterSave);
  });
  if (totalAfterSave >= 1) {
    void import("@/lib/retention/session-retention").then((mod) => {
      mod.observeSessionFirstReflectionSaved();
    });
  }
}
