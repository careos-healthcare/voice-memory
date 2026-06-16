import {
  blindSpotCandidateRankingScore as baseBlindSpotCandidateRankingScore,
  type BuildInsightIngredientProfileInput,
} from "@/lib/insights/insight-ingredient-optimizer";
import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import type { RankedBlindSpotCandidate } from "@/lib/blind-spots/blind-spot-ranking";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type { InsightIngredientProfile, InsightIngredientTier } from "@/types/insight-ingredient-optimizer";
import type { PublicEvidenceQualityTier } from "@/types/a-tier-prioritization";
import type { JournalEntry } from "@/types/journal";
import type { PatternInsightType } from "@/lib/patterns/pattern-engine";

export const A_TIER_CRITERIA = {
  a_tier: "3+ high-value ingredients",
  b_tier: "2 ingredients",
  c_tier: "1 ingredient",
  d_tier: "none",
} as const;

export const EVIDENCE_QUALITY_COPY = {
  sectionLabel: "Evidence quality",
  aTier: "A-Tier",
  bTier: "B-Tier",
  cTier: "C-Tier",
  whyMayMatterLead:
    "Why this may matter — your archive linked several strong signals:",
} as const;

/** Scorecard below this — generic frequency may outrank weak A-tier mixes. */
export const EXTREMELY_LOW_CONFIDENCE_SCORECARD = 28;

const GENERIC_INSIGHT_TYPES = new Set<PatternInsightType>([
  "repeated_phrase",
  "recurring_pattern",
]);

const GENERIC_TYPE_PENALTY: Partial<Record<PatternInsightType, number>> = {
  repeated_phrase: -48,
  recurring_pattern: -42,
  avoidance_signal: -8,
};

export function isPublicEvidenceQualityTier(
  tier: InsightIngredientTier,
): tier is PublicEvidenceQualityTier {
  return tier === "a_tier" || tier === "b_tier" || tier === "c_tier";
}

/** Subtle user-facing label — D-tier returns null (no label). */
export function subtleEvidenceQualityLabel(
  tier: InsightIngredientTier,
): string | null {
  switch (tier) {
    case "a_tier":
      return EVIDENCE_QUALITY_COPY.aTier;
    case "b_tier":
      return EVIDENCE_QUALITY_COPY.bTier;
    case "c_tier":
      return EVIDENCE_QUALITY_COPY.cTier;
    default:
      return null;
  }
}

export function ingredientCountFromInput(
  input: BuildInsightIngredientProfileInput,
): number {
  let count = 0;
  if (input.contradictionPresent) count += 1;
  if (input.costEvidencePresent) count += 1;
  if (input.crossLifeAreaPresent) count += 1;
  if (input.failedPredictionPresent) count += 1;
  return count;
}

export function genericInsightTypePenalty(
  candidate: RankedBlindSpotCandidate,
  profile: InsightIngredientProfile,
  scorecardScore: number,
): number {
  const type = candidate.insight.type;
  if (!GENERIC_INSIGHT_TYPES.has(type)) {
    return 0;
  }

  if (profile.tier === "a_tier") return 0;
  if (profile.tier === "b_tier" && scorecardScore >= 45) return -12;

  const base = GENERIC_TYPE_PENALTY[type] ?? 0;
  if (
    profile.tier === "d_tier" &&
    scorecardScore >= EXTREMELY_LOW_CONFIDENCE_SCORECARD + 40
  ) {
    return Math.round(base * 0.35);
  }
  return base;
}

/**
 * A-tier blind spots beat generic frequency unless confidence is extremely low.
 */
export function blindSpotPrioritizationScore(
  candidate: RankedBlindSpotCandidate,
  profile: InsightIngredientProfile,
  scorecardScore: number,
): number {
  const base = baseBlindSpotCandidateRankingScore(candidate, profile, scorecardScore);
  const genericPenalty = genericInsightTypePenalty(candidate, profile, scorecardScore);

  let tierBoost = 0;
  if (profile.tier === "a_tier") tierBoost += 12;
  if (profile.tier === "b_tier") tierBoost += 4;

  if (
    profile.tier === "a_tier" &&
    GENERIC_INSIGHT_TYPES.has(candidate.insight.type) === false
  ) {
    tierBoost += 8;
  }

  return base + genericPenalty + tierBoost;
}

function formatAreaList(areas: string[]): string {
  const filtered = areas.filter((a) => a !== "General");
  if (filtered.length < 2) return "";
  const [first, second] = filtered;
  return `Appears across ${first?.toLowerCase()} and ${second?.toLowerCase()}.`;
}

export function buildATierWhyMatterBullets(
  review: BlindSpotReviewResult,
  profile: InsightIngredientProfile,
  entries: JournalEntry[],
): string[] {
  if (profile.tier !== "a_tier") return [];

  const bullets: string[] = [];
  const facts = review.evidenceStrengthFacts;
  const areas = review.linkedAreas.filter((a) => a !== "General");

  if (
    profile.presentIngredients.includes("cross_life_area") ||
    facts.lifeAreaCount >= 2
  ) {
    const line = formatAreaList(areas);
    if (line) bullets.push(line);
    else if (areas.length >= 2) {
      bullets.push(
        `May show up across ${areas[0]?.toLowerCase()} and ${areas[1]?.toLowerCase()}.`,
      );
    } else {
      const linked = linkedAreasForEntries(entries, review.archiveEntryIds);
      const crossLine = formatAreaList(linked.map(String));
      if (crossLine) bullets.push(crossLine);
    }
  }

  const patternType = review.reviewId.split(":")[1];
  if (
    profile.presentIngredients.includes("cost_evidence") ||
    review.costEvidenceLines.length > 0
  ) {
    if (patternType === "avoidance_signal") {
      bullets.push("Followed by avoidance later in your archive.");
    } else if (review.costEvidenceLines.length > 0) {
      bullets.push("Later reflections may show a cost after this thread repeats.");
    }
  }

  if (
    profile.presentIngredients.includes("contradiction") ||
    facts.contradictionPresent ||
    review.contradictionNote
  ) {
    bullets.push("May conflict with another belief your reflections keep circling.");
  }

  if (profile.presentIngredients.includes("failed_prediction") || review.predictionEvidenceNote) {
    bullets.push("Later entries may not match what you expected would happen.");
  }

  if (bullets.length === 0) {
    bullets.push(
      "Several high-value signals stacked — worth treating as a working case, not a single quote.",
    );
  }

  return [...new Set(bullets)].slice(0, 3);
}
