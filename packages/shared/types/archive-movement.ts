export type ArchiveMovementKind =
  | "confidence_changed"
  | "evidence_increased"
  | "status_changed"
  | "new_life_area"
  | "contradiction_detected"
  | "cost_evidence_detected"
  | "under_review";

export interface ArchiveMovementUpdate {
  id: string;
  kind: ArchiveMovementKind;
  at: string;
  eyebrow: string;
  headline: string;
  detailLine?: string;
  reason: string;
}

export interface ArchiveMovementRecord extends ArchiveMovementUpdate {
  entryId?: string;
  reflectionCount: number;
}

export type ArchiveMovementEventName = "archive_update_seen" | "archive_update_expanded";

export interface ArchiveMovementEvent {
  name: ArchiveMovementEventName;
  at: string;
  movementId: string;
  kind: ArchiveMovementKind;
}
