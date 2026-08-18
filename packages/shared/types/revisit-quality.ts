export type RevisitQualityClassification =
  | "weak_revisit"
  | "informational_revisit"
  | "meaningful_revisit"
  | "durable_revisit";

export type RevisitQualityFlag =
  | "generic_copy"
  | "overclaimed_copy"
  | "informational_only"
  | "weak_contrast"
  | "fatigue_risk"
  | "high_quality";

export interface RevisitQualityDimensions {
  specificity: number;
  surprise: number;
  beforeAfterContrast: number;
  wordingPreservation: number;
  emotionalDistance: number;
  photoAudioSupport: number;
  followUpConversion: number;
  bookmarkCopyAfterRevisit: number;
  delayedReflectionAfterRevisit: number;
  repeatReopenSameEntry: number;
  genericityRisk: number;
  overclaimRisk: number;
}

export interface RevisitQualityVerdict {
  total: number;
  classification: RevisitQualityClassification;
  dimensions: RevisitQualityDimensions;
  flags: RevisitQualityFlag[];
  suppressed: boolean;
  protected: boolean;
  entryId?: string;
  noteId: string;
  text: string;
}

export interface RevisitQualityReviewRow {
  noteId: string;
  entryId: string;
  text: string;
  total: number;
  classification: RevisitQualityClassification;
  flags: RevisitQualityFlag[];
  dimensions: RevisitQualityDimensions;
  suppressed: boolean;
  protected: boolean;
}

export interface RevisitReflectionQualitySummary {
  revisitCount: number;
  reflectionAfterCount: number;
  conversionRate: string;
  durableCount: number;
  meaningfulCount: number;
}

export interface RevisitFatigueRiskSummary {
  active: boolean;
  recentRevisits: number;
  weakRevisitRatio: number;
  recommendation: string;
}

export interface RevisitQualityDebugReport {
  generatedAt: string;
  hasData: boolean;
  totalCandidates: number;
  bestRevisits: RevisitQualityReviewRow[];
  worstRevisits: RevisitQualityReviewRow[];
  genericCopy: RevisitQualityReviewRow[];
  overclaimedCopy: RevisitQualityReviewRow[];
  reflectionQuality: RevisitReflectionQualitySummary;
  fatigueRisk: RevisitFatigueRiskSummary;
  byClassification: Record<RevisitQualityClassification, number>;
}
