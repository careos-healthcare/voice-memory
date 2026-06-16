export type InsightIngredientKey =
  | "contradiction"
  | "cost_evidence"
  | "cross_life_area"
  | "long_time_span"
  | "failed_prediction";

export type InsightScorecardSurface =
  | "blind_spot"
  | "theory"
  | "prediction"
  | "emerging_pattern"
  | "discover";

export type InsightScoreLabel = "low" | "medium" | "high" | "very_high";

export interface InsightScorecardIngredient {
  key: InsightIngredientKey;
  label: string;
  present: boolean;
  recognitionPrior: number;
  evidenceLine?: string;
}

export interface InsightScorecard {
  insightId: string;
  surface: InsightScorecardSurface;
  headline: string;
  score: number;
  scoreLabel: InsightScoreLabel;
  ingredients: InsightScorecardIngredient[];
  missingIngredients: InsightScorecardIngredient[];
  strongestIngredients: InsightScorecardIngredient[];
  createdAt: string;
  sourceIds: string[];
}

export interface InsightScorecardSurfaceSummary {
  surface: InsightScorecardSurface;
  count: number;
  averageScore: number | null;
}

export interface InsightIngredientHitRate {
  key: InsightIngredientKey;
  label: string;
  presentCount: number;
  hitRate: number | null;
}

export interface InsightScorecardReport {
  generatedAt: string;
  totalScored: number;
  averageScore: number | null;
  highest: InsightScorecard[];
  lowest: InsightScorecard[];
  bySurface: InsightScorecardSurfaceSummary[];
  ingredientHitRates: InsightIngredientHitRate[];
  recommendedPriorityOrder: InsightScorecard[];
  breakthroughComparisonLines: string[];
}
