import type {
  ConversionReasonId,
  PaywallInterestReasonId,
  PaywallRejectionReasonId,
} from "@/types/paywall-attribution";

export const PAYWALL_REJECTION_QUESTION = "What stopped you upgrading?";

export const PAYWALL_INTEREST_QUESTION = "What made Pro interesting?";

export const CONVERSION_REASON_QUESTION = "What convinced you?";

export const PAYWALL_ATTRIBUTION_DISMISS = "Not today";

export const PAYWALL_REJECTION_LABELS: Record<PaywallRejectionReasonId, string> = {
  too_expensive: "Too expensive",
  need_more_proof: "Need more proof",
  just_exploring: "Just exploring",
  not_enough_reflections: "Not enough moments yet",
  not_useful_enough: "Not useful enough",
  prefer_free_tools: "Prefer free tools",
  other: "Other",
};

export const PAYWALL_INTEREST_LABELS: Record<PaywallInterestReasonId, string> = {
  belief_changes: "Belief changes",
  blind_spots: "Blind spots",
  discover: "Discover",
  archive_history: "Archive history",
  confidence_tracking: "Confidence tracking",
  pattern_review: "Pattern review",
  other: "Other",
};

export const CONVERSION_REASON_LABELS: Record<ConversionReasonId, string> = {
  belief_changes: "Belief changes",
  blind_spots: "Blind spots",
  discover: "Discover",
  archive_history: "Archive history",
  confidence_tracking: "Confidence tracking",
  pattern_review: "Pattern review",
  enough_proof: "Saw enough proof",
  price_felt_fair: "Price felt fair",
  other: "Other",
};
