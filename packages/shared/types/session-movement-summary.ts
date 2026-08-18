export type SessionMovementKind =
  | "belief_changed"
  | "confidence_moved"
  | "new_evidence_added"
  | "contradiction_appeared"
  | "belief_weakened"
  | "belief_strengthened"
  | "comparison_point";

export type SessionMovementSurface =
  | "record_complete"
  | "discover"
  | "memory"
  | "blind_spots"
  | "entry";

export interface SessionMovementSummaryView {
  id: string;
  kind: SessionMovementKind;
  headline: string;
  detailLine?: string;
  reason: string;
  theoryId?: string;
}
