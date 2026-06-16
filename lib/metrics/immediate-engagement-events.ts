import type {
  ImmediateEngagementEvent,
  ImmediateEngagementEventName,
  ImmediateNoticeKind,
} from "@/types/immediate-engagement";

export const IMMEDIATE_ENGAGEMENT_EVENTS_KEY = "voicememory_immediate_engagement_events";

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readEvents(): ImmediateEngagementEvent[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(IMMEDIATE_ENGAGEMENT_EVENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ImmediateEngagementEvent[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeEvents(events: ImmediateEngagementEvent[]): void {
  getStorage()?.setItem(
    IMMEDIATE_ENGAGEMENT_EVENTS_KEY,
    JSON.stringify(events.slice(-400)),
  );
}

export function clearImmediateEngagementEventsForEval(): void {
  getStorage()?.removeItem(IMMEDIATE_ENGAGEMENT_EVENTS_KEY);
}

function trackEvent(
  name: ImmediateEngagementEventName,
  meta: {
    followUpId: string;
    entryId: string;
    noticeKind: ImmediateNoticeKind;
  },
): void {
  const events = readEvents();
  events.push({
    name,
    at: new Date().toISOString(),
    followUpId: meta.followUpId,
    entryId: meta.entryId,
    noticeKind: meta.noticeKind,
  });
  writeEvents(events);
}

export function trackFollowupShown(meta: {
  followUpId: string;
  entryId: string;
  noticeKind: ImmediateNoticeKind;
}): void {
  const events = readEvents();
  const seen = events.some(
    (e) => e.name === "followup_shown" && e.followUpId === meta.followUpId,
  );
  if (seen) return;
  trackEvent("followup_shown", meta);
}

export function trackFollowupAnswered(meta: {
  followUpId: string;
  entryId: string;
  noticeKind: ImmediateNoticeKind;
}): void {
  trackEvent("followup_answered", meta);
}

export function readImmediateEngagementEvents(): ImmediateEngagementEvent[] {
  return readEvents();
}

export function countImmediateEngagementEvents(
  name: ImmediateEngagementEventName,
): number {
  return readEvents().filter((e) => e.name === name).length;
}
