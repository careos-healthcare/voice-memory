export const RETURN_TRIGGER_REASON_IDS = [
  "archive_view_changed",
  "theory_stronger",
  "theory_disappeared",
  "new_blind_spot",
  "confidence_changed",
  "wanted_to_record",
  "just_curious",
  "other",
] as const;

export type ReturnTriggerReasonId = (typeof RETURN_TRIGGER_REASON_IDS)[number];

export const RETURN_EXPECTATION_MET_VALUES = ["yes", "partly", "no"] as const;

export type ReturnExpectationMet = (typeof RETURN_EXPECTATION_MET_VALUES)[number];

export interface ReturnTriggerAttributionRecord {
  id: string;
  reason: ReturnTriggerReasonId;
  answeredAt: string;
  hoursSinceLastOpen: number | null;
  expectationMet?: ReturnExpectationMet;
  expectationAnsweredAt?: string;
}

export interface ReturnTriggerReasonOutcomeRow {
  reason: ReturnTriggerReasonId;
  label: string;
  count: number;
  sharePercent: number;
  sevenDayRetentionRate: number | null;
  paywallClickRate: number | null;
  subscriptionRate: number | null;
  breakthroughRate: number | null;
}

export interface ReturnTriggerAttributionReport {
  criticalQuestion: string;
  criticalAnswer: string;
  totalReasonResponses: number;
  totalExpectationResponses: number;
  mostCommonReason: ReturnTriggerReasonId | null;
  mostCommonReasonLabel: string | null;
  byReason: ReturnTriggerReasonOutcomeRow[];
  expectationBreakdown: { met: ReturnExpectationMet; count: number; sharePercent: number }[];
  recentRecords: ReturnTriggerAttributionRecord[];
}
