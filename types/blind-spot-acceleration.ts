import type { BlindSpotEvidenceQuote, BlindSpotReviewReport } from "@/types/blind-spot";

export interface EmergingPattern {
  id: string;
  label: string;
  confidenceLabel: string;
  hypothesis: string;
  evidenceQuotes: BlindSpotEvidenceQuote[];
  matchingReflections: number;
}

export interface CostEvidenceCounts {
  avoidance: number;
  delayedDecisions: number;
  quittingLanguage: number;
  repeatedConflict: number;
  emotionalSpirals: number;
}

export type PredictionPolarity = "negative" | "positive" | "neutral";

export type PredictionOutcomeStatus =
  | "pending"
  | "diverged"
  | "aligned"
  | "unclear";

export interface PredictionCandidate {
  id: string;
  entryId: string;
  predictedAt: string;
  dateLabel: string;
  quote: string;
  triggerPhrase: string;
  polarity: PredictionPolarity;
}

export interface PredictionLaterEvidence {
  entryId: string;
  dateLabel: string;
  quote: string;
}

export interface PredictionReviewItem {
  candidate: PredictionCandidate;
  laterEvidence?: PredictionLaterEvidence;
  outcomeStatus: PredictionOutcomeStatus;
  outcomeSummary: string;
}

export interface PredictionAccuracySummary {
  totalPredictions: number;
  negativePredictions: number;
  negativeDidNotHappen: number;
  failurePredictions: number;
  failureMorePositiveThanExpected: number;
  summaryLines: string[];
}

export interface PredictionReviewReport {
  items: PredictionReviewItem[];
  accuracy: PredictionAccuracySummary;
  hasData: boolean;
}

export interface BlindSpotAccelerationReport {
  emergingPatterns: EmergingPattern[];
  mainReview: BlindSpotReviewReport;
  predictionReview: PredictionReviewReport;
}

/** Evidence-first section order for UI and tests */
export const BLIND_SPOT_EVIDENCE_FIRST_SECTIONS = [
  "evidence",
  "observation",
  "possiblePattern",
  "whyItMayMatter",
] as const;
