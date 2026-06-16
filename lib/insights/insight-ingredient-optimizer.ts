import { blindSpotIdFromReviewId } from "@/lib/blind-spots/blind-spot-quality-storage";
import type { RankedBlindSpotCandidate } from "@/lib/blind-spots/blind-spot-ranking";
import type { EvidenceStrengthLabel, BlindSpotReviewResult } from "@/types/blind-spot";
import type {
  InsightIngredientKey,
  InsightIngredientProfile,
  InsightIngredientTier,
} from "@/types/insight-ingredient-optimizer";

export const HIGH_VALUE_INGREDIENT_ORDER: InsightIngredientKey[] = [
  "contradiction",
  "cost_evidence",
  "cross_life_area",
  "failed_prediction",
];

export const INGREDIENT_OPTIMIZER_WEIGHTS: Record<InsightIngredientKey, number> = {
  contradiction: 50,
  cost_evidence: 45,
  cross_life_area: 40,
  failed_prediction: 25,
};

export const TIER_RANKING_BOOST: Record<InsightIngredientTier, number> = {
  a_tier: 45,
  b_tier: 25,
  c_tier: 8,
  d_tier: -35,
};

export const TIER_LABELS: Record<InsightIngredientTier, string> = {
  a_tier: "A-tier: 3+ high-value ingredients",
  b_tier: "B-tier: 2 high-value ingredients",
  c_tier: "C-tier: 1 high-value ingredient",
  d_tier: "D-tier: no high-value ingredients",
};

export interface BuildInsightIngredientProfileInput {
  reviewId: string;
  blindSpotId?: string;
  contradictionPresent: boolean;
  costEvidencePresent: boolean;
  crossLifeAreaPresent: boolean;
  failedPredictionPresent: boolean;
  evidenceStrength?: EvidenceStrengthLabel;
  scorecardScore?: number;
  createdAt?: string;
}

export interface IngredientOptimizerBoostContext {
  evidenceStrength: EvidenceStrengthLabel;
  scorecardScore: number;
}

function presentKeysFromFlags(input: BuildInsightIngredientProfileInput): InsightIngredientKey[] {
  const present: InsightIngredientKey[] = [];
  if (input.contradictionPresent) present.push("contradiction");
  if (input.costEvidencePresent) present.push("cost_evidence");
  if (input.crossLifeAreaPresent) present.push("cross_life_area");
  if (input.failedPredictionPresent) present.push("failed_prediction");
  return present;
}

export function classifyIngredientTier(
  presentCount: number,
): InsightIngredientTier {
  if (presentCount >= 3) return "a_tier";
  if (presentCount === 2) return "b_tier";
  if (presentCount === 1) return "c_tier";
  return "d_tier";
}

export function describeIngredientTier(profile: InsightIngredientProfile): string {
  const present =
    profile.presentIngredients.length > 0
      ? profile.presentIngredients.join(", ")
      : "none";
  return `${profile.tierLabel} — present: ${present}.`;
}

export function buildInsightIngredientProfile(
  input: BuildInsightIngredientProfileInput,
): InsightIngredientProfile {
  const presentIngredients = presentKeysFromFlags(input);
  const missingIngredients = HIGH_VALUE_INGREDIENT_ORDER.filter(
    (key) => !presentIngredients.includes(key),
  );
  const tier = classifyIngredientTier(presentIngredients.length);
  const optimizerScore = presentIngredients.reduce(
    (sum, key) => sum + INGREDIENT_OPTIMIZER_WEIGHTS[key],
    0,
  );

  return {
    reviewId: input.reviewId,
    blindSpotId: input.blindSpotId ?? blindSpotIdFromReviewId(input.reviewId),
    presentIngredients,
    missingIngredients,
    tier,
    tierLabel: TIER_LABELS[tier],
    optimizerScore,
    createdAt: input.createdAt ?? new Date().toISOString(),
    evidenceStrength: input.evidenceStrength,
    scorecardScore: input.scorecardScore,
  };
}

export function buildInsightIngredientProfileFromCandidate(
  candidate: RankedBlindSpotCandidate,
  headline: string,
  scorecardScore: number,
): InsightIngredientProfile {
  const { insight } = candidate;
  return buildInsightIngredientProfile({
    reviewId: `blind-spot:${insight.type}:${insight.sourceKey}`,
    contradictionPresent:
      candidate.contradictionPresent || insight.type === "contradiction",
    costEvidencePresent: candidate.costEvidenceCount > 0,
    crossLifeAreaPresent: candidate.lifeAreaCount >= 2,
    failedPredictionPresent: candidate.failedPredictionLinked,
    evidenceStrength: candidate.evidenceStrength,
    scorecardScore,
    createdAt: new Date().toISOString(),
  });
}

export function buildInsightIngredientProfileFromReview(
  review: BlindSpotReviewResult,
): InsightIngredientProfile {
  const facts = review.evidenceStrengthFacts;
  return buildInsightIngredientProfile({
    reviewId: review.reviewId,
    contradictionPresent: facts.contradictionPresent || Boolean(review.contradictionNote),
    costEvidencePresent: facts.costEvidenceCount > 0 || review.costEvidenceLines.length > 0,
    crossLifeAreaPresent: facts.lifeAreaCount >= 2 || review.linkedAreas.length >= 2,
    failedPredictionPresent:
      facts.failedPredictionCount > 0 || Boolean(review.predictionEvidenceNote),
    evidenceStrength: review.evidenceStrength,
    scorecardScore: review.scorecard?.score,
    createdAt: review.generatedAt,
  });
}

export function ingredientOptimizerBoost(
  profile: InsightIngredientProfile,
  context?: IngredientOptimizerBoostContext,
): number {
  let boost = TIER_RANKING_BOOST[profile.tier];

  if (profile.tier === "d_tier" && context) {
    const sparesWeak =
      context.evidenceStrength === "very_high" && context.scorecardScore >= 75;
    if (sparesWeak) {
      boost = 0;
    }
  }

  return boost;
}

/** Composite ranking score after gates: optimizer → scorecard tie-break → impact. */
export function blindSpotCandidateRankingScore(
  candidate: RankedBlindSpotCandidate,
  profile: InsightIngredientProfile,
  scorecardScore: number,
): number {
  return (
    ingredientOptimizerBoost(profile, {
      evidenceStrength: candidate.evidenceStrength,
      scorecardScore,
    }) +
    Math.round(scorecardScore * 0.12) +
    candidate.impactScore
  );
}
