import type { BlindSpotQualityOutcomes } from "@/types/blind-spot-quality";

/** Weighted by change signals — not page views or tap metrics. */
const QUALITY_WEIGHTS = {
  surprising: 12,
  uncomfortablyAccurate: 22,
  breakthrough: 28,
  actedDifferently: 24,
  problemImproved: 14,
} as const;

export function computeBlindSpotQualityScore(outcomes: BlindSpotQualityOutcomes): number {
  let score = 0;
  if (outcomes.surprising) score += QUALITY_WEIGHTS.surprising;
  if (outcomes.uncomfortablyAccurate) score += QUALITY_WEIGHTS.uncomfortablyAccurate;
  if (outcomes.breakthrough) score += QUALITY_WEIGHTS.breakthrough;
  if (outcomes.actedDifferently) score += QUALITY_WEIGHTS.actedDifferently;
  if (outcomes.problemImproved) score += QUALITY_WEIGHTS.problemImproved;
  return Math.min(100, score);
}

export function hasAnyQualityOutcome(outcomes: BlindSpotQualityOutcomes): boolean {
  return (
    outcomes.surprising ||
    outcomes.uncomfortablyAccurate ||
    outcomes.breakthrough ||
    outcomes.actedDifferently ||
    outcomes.problemImproved
  );
}
