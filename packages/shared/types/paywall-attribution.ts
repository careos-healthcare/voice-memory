export const PAYWALL_REJECTION_REASON_IDS = [
  "too_expensive",
  "need_more_proof",
  "just_exploring",
  "not_enough_reflections",
  "not_useful_enough",
  "prefer_free_tools",
  "other",
] as const;

export type PaywallRejectionReasonId = (typeof PAYWALL_REJECTION_REASON_IDS)[number];

export const PAYWALL_INTEREST_REASON_IDS = [
  "belief_changes",
  "blind_spots",
  "discover",
  "archive_history",
  "confidence_tracking",
  "pattern_review",
  "other",
] as const;

export type PaywallInterestReasonId = (typeof PAYWALL_INTEREST_REASON_IDS)[number];

export const CONVERSION_REASON_IDS = [
  "belief_changes",
  "blind_spots",
  "discover",
  "archive_history",
  "confidence_tracking",
  "pattern_review",
  "enough_proof",
  "price_felt_fair",
  "other",
] as const;

export type ConversionReasonId = (typeof CONVERSION_REASON_IDS)[number];

export type PaywallAttributionKind = "rejection" | "interest" | "conversion";

export interface PaywallAttributionRecord {
  id: string;
  kind: PaywallAttributionKind;
  reason: string;
  at: string;
  source?: string;
  surface?: string;
}

export interface PaywallAttributionReasonRow {
  reason: string;
  label: string;
  count: number;
  sharePercent: number;
  subscriptionRate: number | null;
  retentionRate: number | null;
  breakthroughRate: number | null;
}

export interface PaywallAttributionReport {
  mainQuestion: string;
  mainAnswer: string;
  totalRejections: number;
  totalInterest: number;
  totalConversions: number;
  topConversionDrivers: PaywallAttributionReasonRow[];
  topRejectionReasons: PaywallAttributionReasonRow[];
  interestByOutcome: PaywallAttributionReasonRow[];
  recentRecords: PaywallAttributionRecord[];
}
