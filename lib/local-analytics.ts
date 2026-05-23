export type LocalAnalyticsEvent = {
  name: string;
  at: string;
  meta?: Record<string, string>;
};

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

export function readLocalEvents(): LocalAnalyticsEvent[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(EVENTS_KEY);
    return raw ? (JSON.parse(raw) as LocalAnalyticsEvent[]) : [];
  } catch {
    return [];
  }
}
