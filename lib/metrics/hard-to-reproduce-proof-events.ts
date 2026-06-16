import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";

export const HARD_TO_REPRODUCE_EVENT_NAMES = {
  seen: "hard_to_reproduce_proof_seen" as const,
  expanded: "hard_to_reproduce_proof_expanded" as const,
};

export function trackHardToReproduceProofSeen(meta?: { surface?: string }): void {
  trackLocalEvent(HARD_TO_REPRODUCE_EVENT_NAMES.seen, { surface: meta?.surface ?? "" });
}

export function trackHardToReproduceProofExpanded(meta?: { surface?: string }): void {
  trackLocalEvent(HARD_TO_REPRODUCE_EVENT_NAMES.expanded, { surface: meta?.surface ?? "" });
}

export function countHardToReproduceProofEvent(
  name: (typeof HARD_TO_REPRODUCE_EVENT_NAMES)[keyof typeof HARD_TO_REPRODUCE_EVENT_NAMES],
): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}
