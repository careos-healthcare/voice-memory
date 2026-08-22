/** Privacy-safe weekly reflection pattern share card — no raw journal text. */
export interface InsightShareCardModel {
  id: string;
  weekRangeLabel: string;
  headline: string;
  patternLines: string[];
  footer: string;
  referralLink: string;
  referralSource: string;
  plainTextShare: string;
}
