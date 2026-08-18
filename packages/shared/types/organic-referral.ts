export const ORGANIC_REFERRAL_STATUS_IDS = ["yes", "thought_about_it", "no"] as const;

export type OrganicReferralStatusId = (typeof ORGANIC_REFERRAL_STATUS_IDS)[number];

export const ORGANIC_REFERRAL_REASON_IDS = [
  "blind_spots",
  "belief_tracking",
  "discover",
  "theory_changes",
  "archive_history",
  "pattern_review",
  "other",
] as const;

export type OrganicReferralReasonId = (typeof ORGANIC_REFERRAL_REASON_IDS)[number];

export const REFERRAL_BLOCKER_IDS = [
  "stronger_insights",
  "more_belief_changes",
  "better_explanations",
  "more_confidence",
  "more_history",
  "not_sure_yet",
] as const;

export type ReferralBlockerId = (typeof REFERRAL_BLOCKER_IDS)[number];

export type OrganicReferralVerdict = "strong" | "weak" | "mixed" | "insufficient_data";

export interface OrganicReferralRecord {
  id: string;
  status: OrganicReferralStatusId;
  answeredAt: string;
  reflectionCount: number;
  referralReason?: OrganicReferralReasonId;
  referralBlocker?: ReferralBlockerId;
  followUpAnsweredAt?: string;
}

export interface OrganicReferralCountRow {
  id: string;
  label: string;
  count: number;
  sharePercent: number;
}

export interface OrganicReferralOutcomeRow {
  status: OrganicReferralStatusId;
  label: string;
  count: number;
  retentionRate: number | null;
  attachmentRate: number | null;
  subscriptionRate: number | null;
}

export interface OrganicReferralReport {
  criticalQuestion: string;
  criticalAnswer: string;
  verdict: OrganicReferralVerdict;
  referralRate: number | null;
  thoughtAboutItRate: number | null;
  yesOrThoughtRate: number | null;
  totalResponses: number;
  referralReasons: OrganicReferralCountRow[];
  referralBlockers: OrganicReferralCountRow[];
  byStatusOutcomes: OrganicReferralOutcomeRow[];
  recentRecords: OrganicReferralRecord[];
}
