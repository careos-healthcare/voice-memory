import type { BlindSpotReaction, EvidenceStrengthLabel } from "@/types/blind-spot";

export type DelayedValidationResponse = "changed_mind" | "still_wrong" | "now_accurate";

export interface BlindSpotFeedbackRecordV2 {
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

export interface DelayedValidationRecord {
  id: string;
  feedbackId: string;
  reviewId: string;
  headline: string;
  reaction: "obvious" | "completely_wrong";
  createdAt: string;
  dueAt: string;
  response?: DelayedValidationResponse;
  respondedAt?: string;
}

export interface BreakthroughCaptureRecord {
  id: string;
  feedbackId: string;
  reviewId: string;
  reaction: "surprising" | "uncomfortably_accurate";
  phrase: string;
  at: string;
}

export interface WowMomentRow {
  reviewId: string;
  headline: string;
  patternType: string;
  wowMomentScore: number;
  reactionCount: number;
}

export interface PatternCategoryRow {
  patternType: string;
  wowMomentScore: number;
  surprisingCount: number;
  uncomfortablyAccurateCount: number;
  obviousCount: number;
  completelyWrongCount: number;
  reactionCount: number;
}

export interface WowBucketRow {
  bucket: string;
  totalReactions: number;
  averageWowScore: number;
  surprisingCount: number;
  uncomfortablyAccurateCount: number;
}

export interface BreakthroughPhraseSummary {
  phrase: string;
  count: number;
}

export interface SurfaceEngagementComparison {
  blindSpotReactions: number;
  blindSpotOpens: number;
  emergingPatternOpens: number;
  predictionReviewOpens: number;
  predictionAccuracyOpens: number;
  /** Opens per blind-spot reaction — lower may mean deeper engagement per visit */
  opensPerReaction: number;
  predictionOpensVsBlindSpotOpens: number;
  emergingOpensVsBlindSpotOpens: number;
}

export interface BlindSpotDiscoveryReport {
  topWowMoments: WowMomentRow[];
  highestRecognitionPatterns: PatternCategoryRow[];
  lowestRecognitionPatterns: PatternCategoryRow[];
  evidenceStrengthVsWow: WowBucketRow[];
  reflectionCountVsWow: WowBucketRow[];
  archiveAgeVsWow: WowBucketRow[];
  surfaceOpens: {
    blindSpotOpened: number;
    emergingPatternOpened: number;
    predictionReviewOpened: number;
    predictionAccuracyOpened: number;
  };
  surfaceEngagement: SurfaceEngagementComparison;
  breakthroughPhrases: BreakthroughPhraseSummary[];
  delayedValidation: {
    pending: number;
    responded: number;
    changedMind: number;
    stillWrong: number;
    nowAccurate: number;
  };
  generatedAt: string;
}
