import {
  clampConfidence,
  explainConfidenceMovement,
  formatConfidenceMovement,
} from "@/lib/theories/theory-confidence-movement";
import { readLatestBlindSpotReviewSnapshot } from "@/lib/blind-spots/blind-spot-review-snapshots";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type { ConfidenceMovementView } from "@/lib/theories/theory-confidence-movement";

/** Map impact score to a cautious 0–100 confidence display (not clinical certainty). */
export function impactScoreToConfidence(estimatedImpactScore: number): number {
  return clampConfidence(35 + Math.round(estimatedImpactScore * 0.55));
}

export function scorecardToConfidence(scorecardScore: number): number {
  return clampConfidence(Math.round(scorecardScore * 0.85));
}

export function buildBlindSpotConfidenceMovement(
  review: BlindSpotReviewResult,
): ConfidenceMovementView {
  const currentConfidence = review.scorecard
    ? scorecardToConfidence(review.scorecard.score)
    : impactScoreToConfidence(review.estimatedImpactScore);

  const prior = readLatestBlindSpotReviewSnapshot();
  const previousConfidence =
    prior && prior.reviewId === review.reviewId
      ? scorecardToConfidence(prior.scorecardScore)
      : undefined;

  const lifeAreaHint =
    review.linkedAreas.length > 0 && review.linkedAreas[0] !== "General"
      ? review.linkedAreas[0]!.toLowerCase()
      : undefined;

  return formatConfidenceMovement({
    currentConfidence,
    previousConfidence,
    lifeAreaHint,
    contradictingCount: review.evidenceStrengthFacts.contradictionPresent ? 1 : 0,
    supportingCount: review.evidenceStrengthFacts.reflectionCount,
  });
}

export function attachBlindSpotConfidenceFields(
  review: BlindSpotReviewResult,
): BlindSpotReviewResult {
  const movement = buildBlindSpotConfidenceMovement(review);
  return {
    ...review,
    currentConfidence: movement.currentConfidence,
    previousConfidence: movement.previousConfidence,
    confidenceDelta: movement.delta,
    confidenceMovementNote: explainConfidenceMovement({
      currentConfidence: movement.currentConfidence,
      previousConfidence: movement.previousConfidence,
      delta: movement.delta,
      lifeAreaHint:
        review.linkedAreas[0] !== "General" ? review.linkedAreas[0] : undefined,
      contradictingCount: review.evidenceStrengthFacts.contradictionPresent ? 1 : 0,
      supportingCount: review.evidenceStrengthFacts.reflectionCount,
    }),
  };
}
