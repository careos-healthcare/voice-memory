export type ReturnReason =
  | "bothering_me"
  | "decision"
  | "recurring_problem"
  | "review_past_thoughts"
  | "curious_what_noticed"
  | "habit"
  | "other";

export type SessionOutcome =
  | "yes_differently"
  | "yes_clearer"
  | "somewhat"
  | "not_really";

export type FirstValueMomentKind =
  | "blind_spot_viewed"
  | "prediction_review_viewed"
  | "emerging_pattern_viewed"
  | "breakthrough_captured"
  | "second_session_reached";

export interface ReturnReasonRecord {
  id: string;
  reason: ReturnReason;
  otherText?: string;
  sessionNumber: number;
  at: string;
  archiveSize: number;
}

export interface SessionOutcomeRecord {
  id: string;
  sessionNumber: number;
  outcome: SessionOutcome;
  at: string;
}

export interface FirstValueMomentRecord {
  kind: FirstValueMomentKind;
  at: string;
  daysSinceFirstVisit: number;
}

export interface FirstValueSnapshot {
  firstVisitAt: string | null;
  moments: FirstValueMomentRecord[];
  timeToFirstValueDays: number | null;
  timeToFirstValueKind: FirstValueMomentKind | null;
}

export interface ReturnReasonBreakdown {
  reason: ReturnReason;
  label: string;
  count: number;
  share: number;
  averageWowScore: number;
  averageHelpfulness: number;
  averageArchiveSize: number;
}

export interface RetentionSignalScore {
  returnRate: number;
  sessionCount: number;
  returnReasonCount: number;
  averageWowScore: number;
  averageHelpfulness: number;
  breakthroughRate: number;
  abandonmentSignalRate: number;
}

export interface RetentionInsightLine {
  question: string;
  answer: string;
}

export interface RetentionDiscoveryReport {
  returnReasons: ReturnReasonBreakdown[];
  mostCommonReturnReason: ReturnReason | null;
  firstValue: FirstValueSnapshot;
  signalScore: RetentionSignalScore;
  insights: RetentionInsightLine[];
  generatedAt: string;
}
