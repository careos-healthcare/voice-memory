import type { EvidenceStrengthLabel } from "@/types/blind-spot";

export type InsightIngredientKey =
  | "contradiction"
  | "cost_evidence"
  | "cross_life_area"
  | "failed_prediction";

export type InsightIngredientTier = "a_tier" | "b_tier" | "c_tier" | "d_tier";

export type InsightOptimizerRecommendation =
  | "prioritize_a_tier"
  | "prioritize_b_tier"
  | "insufficient_data";

export interface InsightIngredientProfile {
  reviewId: string;
  blindSpotId: string;
  presentIngredients: InsightIngredientKey[];
  missingIngredients: InsightIngredientKey[];
  tier: InsightIngredientTier;
  tierLabel: string;
  optimizerScore: number;
  createdAt: string;
  evidenceStrength?: EvidenceStrengthLabel;
  scorecardScore?: number;
}

export interface InsightIngredientTierOutcomeRates {
  tier: InsightIngredientTier;
  tierLabel: string;
  count: number;
  surprisingRate: number | null;
  uncomfortablyAccurateRate: number | null;
  breakthroughRate: number | null;
  actedDifferentlyRate: number | null;
  problemImprovedRate: number | null;
  overallSuccessRate: number | null;
}

export interface InsightIngredientOutcomeRates {
  key: InsightIngredientKey;
  label: string;
  presentCount: number;
  absentCount: number;
  presentSuccessRate: number | null;
  absentSuccessRate: number | null;
}

export interface InsightIngredientOptimizerMultiplier {
  label: string;
  multiplier: number | null;
  line: string;
}

export interface InsightIngredientOptimizerReport {
  generatedAt: string;
  totalProfiles: number;
  tierCounts: Record<InsightIngredientTier, number>;
  tierOutcomeRates: InsightIngredientTierOutcomeRates[];
  ingredientOutcomeRates: InsightIngredientOutcomeRates[];
  successMultipliers: InsightIngredientOptimizerMultiplier[];
  recommendation: InsightOptimizerRecommendation;
  recommendationLine: string;
  lowSampleWarning: boolean;
  lines: string[];
}
