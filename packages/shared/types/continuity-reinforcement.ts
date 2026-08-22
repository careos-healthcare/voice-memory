export type ContinuityReinforcementSurface =
  | "discover"
  | "blind_spots"
  | "theories"
  | "memory"
  | "updates";

export type ContinuityStripKind =
  | "theory_first_appeared"
  | "cross_life_areas"
  | "confidence_change"
  | "reflection_count"
  | "still_testing"
  | "archive_connecting";

export interface ContinuityStripMessage {
  id: string;
  kind: ContinuityStripKind;
  text: string;
}
