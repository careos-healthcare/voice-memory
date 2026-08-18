export type ArchiveValueStage =
  | "one_data_point"
  | "possible_repeat"
  | "pattern_forming"
  | "theory_under_review"
  | "pattern_review_unlocked";

export interface ArchiveValueSnapshot {
  reflectionCount: number;
  stage: ArchiveValueStage;
  repeatedThemeCount: number;
  theoriesUnderReviewCount: number;
  crossLifeAreaPatternCount: number;
  contradictionCount: number;
  costEvidenceCount: number;
  nextMilestoneCopy: string;
  valueCopy: string;
  progressPercent: number;
  readyForPatternReview: boolean;
  ctaHref: string;
  ctaLabel: string;
}

export interface ArchiveValueProgressionRates {
  oneToTwo: number | null;
  twoToThree: number | null;
  threeToFour: number | null;
  fourToFive: number | null;
}

export interface ArchiveValueMetricsReport {
  generatedAt: string;
  stageCounts: Record<ArchiveValueStage, number>;
  bannerShownCount: number;
  bannerCtaClickedCount: number;
  ladderSeenCount: number;
  progressionRates: ArchiveValueProgressionRates;
  currentReflectionCount: number;
  lines: string[];
}
