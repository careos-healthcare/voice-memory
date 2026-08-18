import type { BreakthroughInsightProfile } from "@/types/breakthrough-tracking";
import type { EvidenceStrengthLabel } from "@/types/blind-spot";
import type { BlindSpotExperimentIngredient } from "@/types/blind-spot-experiment";

export type ExperimentCommitmentStatus = "pending" | "tried" | "not_tried" | "dismissed";

export type ExperimentMetricIngredient =
  | "contradiction"
  | "cost_evidence"
  | "cross_life_area"
  | "failed_prediction"
  | "long_span";

export type ExperimentFollowUpAnswer =
  | "caught_earlier"
  | "after_the_fact"
  | "no"
  | "not_sure";

export interface BlindSpotExperimentCommitment {
  commitmentId: string;
  reviewId: string;
  blindSpotId: string;
  headline: string;
  experimentText: string;
  experimentIngredient: BlindSpotExperimentIngredient;
  metricIngredients: ExperimentMetricIngredient[];
  evidenceStrength: EvidenceStrengthLabel;
  scorecardScore: number;
  insightProfile: BreakthroughInsightProfile;
  createdAt: string;
  dueAt: string;
  status: ExperimentCommitmentStatus;
  followUpAnswer?: ExperimentFollowUpAnswer;
  followUpAnsweredAt?: string;
}

export interface ExperimentIngredientMetricRow {
  ingredient: ExperimentMetricIngredient;
  label: string;
  commitments: number;
  followUpsCompleted: number;
  caughtEarlier: number;
  caughtEarlierRate: number | null;
}

export interface BlindSpotExperimentLoopReport {
  generatedAt: string;
  eligibleExperimentSurfaces: number;
  commitmentCount: number;
  commitmentRate: number | null;
  dueFollowUpCount: number;
  followUpCompletedCount: number;
  followUpCompletionRate: number | null;
  caughtEarlierCount: number;
  caughtEarlierRate: number | null;
  byIngredient: ExperimentIngredientMetricRow[];
  lines: string[];
}
