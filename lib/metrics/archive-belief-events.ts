import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type { ArchiveBeliefEventName } from "@/types/archive-belief";

export const ARCHIVE_BELIEF_EVENTS_KEY = "voicememory_archive_belief_events";

export const ARCHIVE_BELIEF_EVENT_NAMES = {
  viewed: "archive_belief_viewed" as const,
  expanded: "archive_belief_expanded" as const,
  changeViewed: "belief_change_viewed" as const,
  timelineViewed: "belief_timeline_viewed" as const,
};

function countNamed(name: string): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}

export function trackArchiveBeliefViewed(meta?: {
  theoryId?: string;
  surface?: string;
}): void {
  trackLocalEvent(ARCHIVE_BELIEF_EVENT_NAMES.viewed, {
    theoryId: meta?.theoryId ?? "",
    surface: meta?.surface ?? "",
  });
}

export function trackArchiveBeliefExpanded(meta?: {
  theoryId?: string;
  surface?: string;
}): void {
  trackLocalEvent(ARCHIVE_BELIEF_EVENT_NAMES.expanded, {
    theoryId: meta?.theoryId ?? "",
    surface: meta?.surface ?? "",
  });
}

export function trackBeliefChangeViewed(meta?: {
  theoryId?: string;
  surface?: string;
}): void {
  trackLocalEvent(ARCHIVE_BELIEF_EVENT_NAMES.changeViewed, {
    theoryId: meta?.theoryId ?? "",
    surface: meta?.surface ?? "",
  });
}

export function trackBeliefTimelineViewed(meta?: { theoryId?: string }): void {
  trackLocalEvent(ARCHIVE_BELIEF_EVENT_NAMES.timelineViewed, {
    theoryId: meta?.theoryId ?? "",
  });
}

export function countArchiveBeliefEvent(name: ArchiveBeliefEventName): number {
  return countNamed(name);
}

export function clearArchiveBeliefEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const names = new Set(Object.values(ARCHIVE_BELIEF_EVENT_NAMES));
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name as ArchiveBeliefEventName));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}
