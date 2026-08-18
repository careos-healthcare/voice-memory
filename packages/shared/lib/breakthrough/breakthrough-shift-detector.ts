import type { SessionMovementKind } from "@/types/session-movement-summary";

/** Minimum confidence swing to surface a breakthrough card in feeds. */
export const BREAKTHROUGH_CONFIDENCE_DELTA_THRESHOLD = 10;

const BREAKTHROUGH_MOVEMENT_KINDS = new Set<SessionMovementKind>([
  "belief_changed",
  "belief_weakened",
  "belief_strengthened",
  "contradiction_appeared",
]);

export interface BreakthroughShiftInput {
  confidenceDelta?: number;
  movementKind?: SessionMovementKind | null;
  statusChanged?: boolean;
}

export function isBreakthroughShift(input: BreakthroughShiftInput): boolean {
  if (input.statusChanged) return true;
  if (
    input.movementKind != null &&
    BREAKTHROUGH_MOVEMENT_KINDS.has(input.movementKind)
  ) {
    return true;
  }
  const delta = Math.abs(input.confidenceDelta ?? 0);
  return delta >= BREAKTHROUGH_CONFIDENCE_DELTA_THRESHOLD;
}

function parseConfidenceDeltaFromDetail(detailLine?: string): number | undefined {
  if (!detailLine) return undefined;
  const match = detailLine.match(/(\d+)%\s*→\s*(\d+)%/);
  if (!match) return undefined;
  return Math.abs(Number(match[2]) - Number(match[1]));
}

/** Maps a post-save session movement summary to breakthrough feed eligibility. */
export function isBreakthroughFromSessionMovement(input: {
  kind: SessionMovementKind;
  detailLine?: string;
}): boolean {
  return isBreakthroughShift({
    movementKind: input.kind,
    statusChanged: input.kind === "belief_changed",
    confidenceDelta: parseConfidenceDeltaFromDetail(input.detailLine),
  });
}

export const BREAKTHROUGH_FEED_COPY = {
  eyebrow: "Breakthrough",
  title: "Something meaningful shifted in your archive",
  body: "This is a high-signal change — worth revisiting when you have a quiet moment.",
} as const;
