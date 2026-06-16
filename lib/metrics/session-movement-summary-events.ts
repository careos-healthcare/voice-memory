import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";

export const SESSION_MOVEMENT_EVENT_NAMES = {
  seen: "session_movement_summary_seen" as const,
  expanded: "session_movement_summary_expanded" as const,
};

export function trackSessionMovementSummarySeen(meta?: {
  kind?: string;
  surface?: string;
}): void {
  trackLocalEvent(SESSION_MOVEMENT_EVENT_NAMES.seen, {
    kind: meta?.kind ?? "",
    surface: meta?.surface ?? "",
  });
}

export function trackSessionMovementSummaryExpanded(meta?: {
  kind?: string;
  surface?: string;
}): void {
  trackLocalEvent(SESSION_MOVEMENT_EVENT_NAMES.expanded, {
    kind: meta?.kind ?? "",
    surface: meta?.surface ?? "",
  });
}

export function countSessionMovementSummaryEvent(
  name: (typeof SESSION_MOVEMENT_EVENT_NAMES)[keyof typeof SESSION_MOVEMENT_EVENT_NAMES],
): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}
