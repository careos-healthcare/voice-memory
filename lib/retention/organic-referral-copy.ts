import type {
  OrganicReferralReasonId,
  OrganicReferralStatusId,
  ReferralBlockerId,
} from "@/types/organic-referral";

export const ORGANIC_REFERRAL_QUESTION = "Have you told anyone about ArchiveMe?";

export const ORGANIC_REFERRAL_REASON_QUESTION = "What did you tell them?";

export const REFERRAL_BLOCKER_QUESTION = "What would make this worth recommending?";

export const ORGANIC_REFERRAL_DISMISS = "Skip";

export const ORGANIC_REFERRAL_STATUS_LABELS: Record<OrganicReferralStatusId, string> = {
  yes: "Yes",
  thought_about_it: "Thought about it",
  no: "No",
};

export const ORGANIC_REFERRAL_REASON_LABELS: Record<OrganicReferralReasonId, string> = {
  blind_spots: "Blind spots",
  belief_tracking: "Belief tracking",
  discover: "Discover",
  theory_changes: "Theory changes",
  archive_history: "Archive history",
  pattern_review: "Pattern review",
  other: "Other",
};

export const REFERRAL_BLOCKER_LABELS: Record<ReferralBlockerId, string> = {
  stronger_insights: "Stronger insights",
  more_belief_changes: "More belief changes",
  better_explanations: "Better explanations",
  more_confidence: "More confidence in accuracy",
  more_history: "More history",
  not_sure_yet: "Not sure yet",
};

export const ORGANIC_REFERRAL_STRONG_YES_PERCENT = 20;
export const ORGANIC_REFERRAL_STRONG_YES_OR_THOUGHT_PERCENT = 40;
export const ORGANIC_REFERRAL_WEAK_YES_PERCENT = 10;
