import type { TheoryNotificationType } from "@/types/theory-notification";

export const BREAKTHROUGH_TYPES = [
  "noticed_pattern",
  "acted_differently",
  "caught_it_earlier",
  "theory_was_right",
  "theory_no_longer_fits",
  "behavior_changed",
  "blind_spot_resolved",
] as const;

export type BreakthroughType = (typeof BREAKTHROUGH_TYPES)[number];

export const BREAKTHROUGH_PROMPT_ANSWERS = ["yes", "not_sure", "no"] as const;

export type BreakthroughPromptAnswer = (typeof BREAKTHROUGH_PROMPT_ANSWERS)[number];

export interface BreakthroughInsightProfile {
  hasContradiction: boolean;
  hasPredictionFailure: boolean;
  hasCostEvidence: boolean;
  hasCrossLifeArea: boolean;
  hasLongTimeSpan: boolean;
}

export interface BreakthroughAttribution {
  relatedTheoryId?: string;
  relatedBlindSpotId?: string;
  relatedNotificationId?: string;
  relatedNotificationType?: TheoryNotificationType;
  lastDiscoverVisitAt?: string;
  insightProfile?: BreakthroughInsightProfile;
}

export interface BreakthroughEvent {
  breakthroughId: string;
  type: BreakthroughType;
  relatedTheoryId?: string;
  relatedBlindSpotId?: string;
  note?: string;
  createdAt: string;
  answer: BreakthroughPromptAnswer;
  promptId: string;
  attribution: BreakthroughAttribution;
}

export interface BreakthroughPromptOffer {
  id: string;
  question: string;
  surface: "blind_spot" | "theory";
}

export interface InsightDimensionBreakdown {
  dimension: keyof BreakthroughInsightProfile;
  label: string;
  insightCount: number;
  breakthroughYes: number;
  behaviorChangeYes: number;
  breakthroughRate: number | null;
  behaviorChangeRate: number | null;
}

export interface BreakthroughByTheoryTypeRow {
  theoryType: string;
  breakthroughs: number;
  perHundred: number | null;
}

export interface BreakthroughTrackingReport {
  generatedAt: string;
  totalBreakthroughs: number;
  totalPromptResponses: number;
  breakthroughRate: number | null;
  breakthroughsPer100Insights: number | null;
  breakthroughsPerNotification: number | null;
  insightExposureCount: number;
  openedNotificationCount: number;
  byTheoryType: BreakthroughByTheoryTypeRow[];
  winningInsightTitle: string;
  insightDimensions: InsightDimensionBreakdown[];
  behaviorChangeTypes: BreakthroughType[];
  lines: string[];
}
