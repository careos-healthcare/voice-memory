import type { InsightIngredientProfile } from "@/types/insight-ingredient-optimizer";
import type { CostEvidenceCounts } from "@/types/blind-spot-acceleration";
import type { BlindSpotReviewChanges } from "@/types/blind-spot-review-snapshot";
import type { BlindSpotExperiment } from "@/types/blind-spot-experiment";
import type { InsightScorecard } from "@/types/insight-scorecard";

export type BlindSpotReaction =
  | "obvious"
  | "interesting"
  | "surprising"
  | "uncomfortably_accurate"
  | "completely_wrong";

/** @deprecated Use BlindSpotReaction */
export type BlindSpotFeedbackRating = "accurate" | "not_accurate" | "not_sure";

export interface BlindSpotFeedbackRecord {
  id: string;
  reviewId: string;
  reaction: BlindSpotReaction;
  comment?: string;
  at: string;
  headline: string;
  evidenceStrength: EvidenceStrengthLabel;
  estimatedImpactScore: number;
  reflectionCount: number;
  archiveAgeDays: number;
  patternType: string;
}

export interface BlindSpotMetrics {
  totalReviews: number;
  obviousRate: number;
  interestingRate: number;
  surprisingRate: number;
  uncomfortablyAccurateRate: number;
  completelyWrongRate: number;
  selfRecognitionScore: number;
  holyShitScore: number;
  failureScore: number;
}

export interface BlindSpotPerformanceRow {
  reviewId: string;
  headline: string;
  reviewCount: number;
  selfRecognitionCount: number;
  holyShitCount: number;
  failureCount: number;
}

export interface EvidenceStrengthReactionBucket {
  evidenceStrength: EvidenceStrengthLabel;
  total: number;
  obvious: number;
  interesting: number;
  surprising: number;
  uncomfortablyAccurate: number;
  completelyWrong: number;
  selfRecognitionCount: number;
}

export interface BlindSpotValidationReport {
  metrics: BlindSpotMetrics;
  topPerforming: BlindSpotPerformanceRow[];
  worstPerforming: BlindSpotPerformanceRow[];
  evidenceStrengthCorrelation: EvidenceStrengthReactionBucket[];
  generatedAt: string;
}

export type EvidenceStrengthLabel = "low" | "medium" | "high" | "very_high";

export type BlindSpotEmptyReason = "insufficient_reflections" | "weak_evidence";

export interface BlindSpotEvidenceQuote {
  entryId: string;
  dateLabel: string;
  quote: string;
}

export interface EvidenceStrengthFacts {
  reflectionCount: number;
  spanLabel: string;
  spanDays: number;
  richSpanLabel: string;
  lifeAreaCount: number;
  lifeAreas: string[];
  lifeAreaSpreadLabel?: string;
  contradictionPresent: boolean;
  failedPredictionCount: number;
  costEvidenceCount: number;
  specificityScore: number;
  skepticPass: boolean;
}

export interface BlindSpotReviewResult {
  reviewId: string;
  headline: string;
  /** Evidence-first observation before interpretation */
  observation: string;
  possibleBelief: string;
  pattern: string;
  costEvidence: CostEvidenceCounts;
  costEvidenceLines: string[];
  likelyCost: string;
  evidenceQuotes: BlindSpotEvidenceQuote[];
  evidenceStrength: EvidenceStrengthLabel;
  evidenceStrengthFacts: EvidenceStrengthFacts;
  linkedAreas: string[];
  alternativeToTest: string;
  ifThisDisappeared: string;
  whyThisMatters: string;
  disclaimer: string;
  reflectionCount: number;
  archiveEntryIds: string[];
  estimatedImpactScore: number;
  generatedAt: string;
  rootBeliefHypothesis?: string;
  contradictionNote?: string;
  predictionEvidenceNote?: string;
  possibleCostLead?: string;
  specificityScore: number;
  scorecard?: InsightScorecard;
  experiment?: BlindSpotExperiment;
  ingredientProfile?: InsightIngredientProfile;
  /** Cautious archive confidence — not a diagnosis or verdict. */
  currentConfidence?: number;
  previousConfidence?: number;
  confidenceDelta?: number;
  confidenceMovementNote?: string;
  /** A-tier only — why users should care (hedged). */
  whyMatterBullets?: string[];
}

export interface BlindSpotReviewEmpty {
  kind: "empty";
  reason: BlindSpotEmptyReason;
  reflectionCount: number;
  message: string;
}

export interface BlindSpotReviewReady {
  kind: "ready";
  review: BlindSpotReviewResult;
  sinceLastTime: BlindSpotReviewChanges;
}

export type BlindSpotReviewReport = BlindSpotReviewEmpty | BlindSpotReviewReady;

/** @deprecated Use BlindSpotEvidenceQuote */
export type BlindSpotEvidence = BlindSpotEvidenceQuote;
