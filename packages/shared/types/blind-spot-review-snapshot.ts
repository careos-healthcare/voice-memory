import type { EvidenceStrengthLabel } from "@/types/blind-spot";

export type BlindSpotChangeKind =
  | "stronger_evidence"
  | "new_life_area"
  | "new_contradiction"
  | "new_cost_evidence"
  | "softened_resolved"
  | "changed_root_belief";

export interface BlindSpotReviewSnapshot {
  snapshotId: string;
  reviewId: string;
  savedAt: string;
  headline: string;
  rootBeliefHypothesis?: string;
  evidenceStrength: EvidenceStrengthLabel;
  evidenceStrengthScore: number;
  lifeAreas: string[];
  lifeAreaCount: number;
  spanDays: number;
  contradictionPresent: boolean;
  costEvidenceCount: number;
  failedPredictionCount: number;
  entryIds: string[];
  matchingReflectionCount: number;
  archiveReflectionCount: number;
  archiveEntryIds: string[];
  scorecardScore: number;
  patternType: string;
}

export interface BlindSpotReviewChangeLine {
  kind: BlindSpotChangeKind;
  text: string;
}

export interface BlindSpotReviewChanges {
  hasPriorSnapshot: boolean;
  hasMeaningfulChange: boolean;
  sectionTitle: string;
  noChangeMessage?: string;
  lines: BlindSpotReviewChangeLine[];
}
