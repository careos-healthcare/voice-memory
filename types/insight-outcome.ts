import type { EvidenceStrengthLabel } from "@/types/blind-spot";

export type InsightOutcomeInsightType = "blind_spot" | "theory";

export const INSIGHT_OUTCOME_RESPONSES = [
  "no_change",
  "noticed_pattern",
  "caught_it_earlier",
  "acted_differently",
  "problem_improved",
  "theory_stopped_fitting",
] as const;

export type InsightOutcomeResponse = (typeof INSIGHT_OUTCOME_RESPONSES)[number];

export type InsightOutcomeTrigger =
  | "experiment_followup"
  | "breakthrough_followup"
  | "theory_revisit"
  | "delayed_validation";

export interface InsightOutcomeEvent {
  id: string;
  insightId: string;
  insightType: InsightOutcomeInsightType;
  scorecardScore: number;
  contradictionPresent: boolean;
  costEvidencePresent: boolean;
  crossLifeAreaPresent: boolean;
  failedPredictionPresent: boolean;
  longSpanPresent: boolean;
  createdAt: string;
  evidenceStrength?: EvidenceStrengthLabel;
  confidenceLabel?: string;
  patternType?: string;
  theoryType?: string;
  trigger?: InsightOutcomeTrigger;
  outcome?: InsightOutcomeResponse;
  respondedAt?: string;
}

export type InsightOutcomeIngredient =
  | "contradiction"
  | "cost_evidence"
  | "cross_life_area"
  | "failed_prediction"
  | "long_span";

export interface InsightOutcomeIngredientRow {
  ingredient: InsightOutcomeIngredient;
  label: string;
  appearances: number;
  improvementCount: number;
  improvementRate: number | null;
}

export interface InsightOutcomeProfileRow {
  profileKey: string;
  label: string;
  appearances: number;
  successCount: number;
  successRate: number | null;
  insightType: InsightOutcomeInsightType;
}

export interface InsightOutcomeFunnelStep {
  outcome: InsightOutcomeResponse;
  label: string;
  count: number;
  share: number | null;
}

export interface InsightOutcomeReport {
  generatedAt: string;
  totalResponses: number;
  overallOutcomeRate: number | null;
  noticedPatternRate: number | null;
  caughtEarlierRate: number | null;
  actedDifferentlyRate: number | null;
  problemImprovedRate: number | null;
  theoryStoppedFittingRate: number | null;
  noChangeRate: number | null;
  funnel: InsightOutcomeFunnelStep[];
  byIngredient: InsightOutcomeIngredientRow[];
  topProfiles: InsightOutcomeProfileRow[];
  weakestProfiles: InsightOutcomeProfileRow[];
  winningInsightTitle: string;
  lines: string[];
}
