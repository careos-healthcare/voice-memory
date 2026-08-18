import type { EvidenceStrengthLabel } from "@/types/blind-spot";

export type InsightSurface = "blind_spot" | "theory" | "emerging" | "prediction";

export type InsightReactionTier = "strong" | "weak" | "neutral";

export interface InsightIngredientMetrics {
  evidenceQuoteCount: number;
  timeSpanDays: number;
  lifeAreaCount: number;
  contradictionCount: number;
  predictionFailureCount: number;
  costEvidenceCount: number;
  rootBeliefPresent: number;
  specificityScore: number;
  confidenceScore: number;
  evidenceStrength: EvidenceStrengthLabel;
  evidenceStrengthScore: number;
}

export interface InsightFeedbackRow {
  id: string;
  surface: InsightSurface;
  referenceId: string;
  headline: string;
  reaction: string;
  reactionTier: InsightReactionTier;
  wowScore: number;
  ingredients: InsightIngredientMetrics;
  at: string;
}

export interface IngredientComparisonRow {
  key: keyof InsightIngredientMetrics;
  label: string;
  strongAverage: number | null;
  weakAverage: number | null;
  delta: number | null;
}

export interface SelfRecognitionIngredientsReport {
  generatedAt: string;
  strongReactionCount: number;
  weakReactionCount: number;
  neutralReactionCount: number;
  strongestInsights: InsightFeedbackRow[];
  weakestInsights: InsightFeedbackRow[];
  ingredientComparisons: IngredientComparisonRow[];
  commonStrongIngredients: string[];
  commonWeakIngredients: string[];
  /** Ingredient deltas that correlate with Surprising / Uncomfortably Accurate vs obvious / wrong. */
  accuracyCorrelationLines: string[];
  bySurface: Array<{
    surface: InsightSurface;
    strongCount: number;
    weakCount: number;
  }>;
}
