import { trackLocalEvent } from "@/lib/local-analytics";

export const OPEN_LOOP_EVENTS = {
  created: "open_loop_created",
  promptShown: "open_loop_prompt_shown",
  promptDismissed: "open_loop_prompt_dismissed",
  resurfacingShown: "open_loop_resurfacing_shown",
  entryReopened: "open_loop_entry_reopened",
  softened: "open_loop_softened",
  closed: "open_loop_closed",
  reflectionAfterResurface: "open_loop_reflection_after_resurface",
} as const;

export type OpenLoopEventName = (typeof OPEN_LOOP_EVENTS)[keyof typeof OPEN_LOOP_EVENTS];

export function trackOpenLoopCreated(openLoopId: string, sourceEntryId: string): void {
  trackLocalEvent(OPEN_LOOP_EVENTS.created, { openLoopId, sourceEntryId });
}

export function trackOpenLoopPromptShown(entryId: string): void {
  trackLocalEvent(OPEN_LOOP_EVENTS.promptShown, { entryId });
}

export function trackOpenLoopPromptDismissed(entryId: string): void {
  trackLocalEvent(OPEN_LOOP_EVENTS.promptDismissed, { entryId });
}

export function trackOpenLoopResurfacingShown(openLoopId: string, line: string): void {
  trackLocalEvent(OPEN_LOOP_EVENTS.resurfacingShown, {
    openLoopId,
    line: line.slice(0, 120),
  });
}

export function trackOpenLoopEntryReopened(openLoopId: string, entryId: string): void {
  trackLocalEvent(OPEN_LOOP_EVENTS.entryReopened, { openLoopId, entryId });
}

export function trackOpenLoopSoftened(openLoopId: string): void {
  trackLocalEvent(OPEN_LOOP_EVENTS.softened, { openLoopId });
}

export function trackOpenLoopClosed(openLoopId: string): void {
  trackLocalEvent(OPEN_LOOP_EVENTS.closed, { openLoopId });
}

export function trackOpenLoopReflectionAfterResurface(
  openLoopId: string,
  entryId: string,
): void {
  trackLocalEvent(OPEN_LOOP_EVENTS.reflectionAfterResurface, { openLoopId, entryId });
}
