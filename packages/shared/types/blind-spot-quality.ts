import type { EvidenceStrengthLabel } from "@/types/blind-spot";

/** Stored when a blind spot review is generated — not engagement metrics. */
export interface BlindSpotQualityRecord {
  reviewId: string;
  blindSpotId: string;
  headline: string;
  scorecardScore: number;
  evidenceStrength: EvidenceStrengthLabel;
  contradictionPresent: boolean;
  costEvidencePresent: boolean;
  crossLifeAreaPresent: boolean;
  failedPredictionPresent: boolean;
  longSpanPresent: boolean;
  rootBeliefPresent: boolean;
  generatedAt: string;
}

/** Later signals merged from reactions, breakthroughs, and outcome prompts. */
export interface BlindSpotQualityOutcomes {
  surprising: boolean;
  uncomfortablyAccurate: boolean;
  breakthrough: boolean;
  actedDifferently: boolean;
  problemImproved: boolean;
}

export interface BlindSpotQualityEnrichedRecord extends BlindSpotQualityRecord {
  outcomes: BlindSpotQualityOutcomes;
  blindSpotQualityScore: number;
}

export type BlindSpotQualityIngredientKey =
  | "contradiction"
  | "cost_evidence"
  | "cross_life_area"
  | "failed_prediction"
  | "long_span"
  | "root_belief";

export interface BlindSpotQualityIngredientFrequency {
  key: BlindSpotQualityIngredientKey;
  label: string;
  count: number;
  frequency: number | null;
}

export interface BlindSpotQualitySuccessMultiplier {
  key: BlindSpotQualityIngredientKey;
  label: string;
  multiplier: number | null;
  topShare: number | null;
  bottomShare: number | null;
  line: string;
}

export interface BlindSpotQualityRankedRow {
  reviewId: string;
  blindSpotId: string;
  headline: string;
  blindSpotQualityScore: number;
  scorecardScore: number;
  evidenceStrength: EvidenceStrengthLabel;
  outcomes: BlindSpotQualityOutcomes;
  generatedAt: string;
}

export interface BlindSpotQualityReport {
  generatedAt: string;
  totalRecords: number;
  recordsWithOutcomes: number;
  topPerformers: BlindSpotQualityRankedRow[];
  bottomPerformers: BlindSpotQualityRankedRow[];
  ingredientFrequencies: BlindSpotQualityIngredientFrequency[];
  successMultipliers: BlindSpotQualitySuccessMultiplier[];
  lines: string[];
}
