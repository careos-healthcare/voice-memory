export const INSIGHT_SHARE_REFERRAL_BASE = "https://archiveme.app/invite";
export const INSIGHT_SHARE_REFERRAL_REF = "archive_invite";
export const INSIGHT_SHARE_REFERRAL_SOURCE = "weekly_review";

/** Fixed attribution link for weekly insight share cards — no user ids. */
export function buildInsightShareReferralLink(): string {
  return `${INSIGHT_SHARE_REFERRAL_BASE}?ref=${INSIGHT_SHARE_REFERRAL_REF}&source=${INSIGHT_SHARE_REFERRAL_SOURCE}`;
}
