import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";

export const EFFORT_COMPOUNDS_EVENT_NAMES = {
  seen: "effort_compounds_seen" as const,
};

export function trackEffortCompoundsSeen(meta?: {
  reflectionCount?: number;
  trigger?: string;
}): void {
  trackLocalEvent(EFFORT_COMPOUNDS_EVENT_NAMES.seen, {
    reflectionCount: String(meta?.reflectionCount ?? ""),
    trigger: meta?.trigger ?? "",
  });
}

export function countEffortCompoundsSeen(): number {
  return readLocalEvents().filter((e) => e.name === EFFORT_COMPOUNDS_EVENT_NAMES.seen).length;
}
