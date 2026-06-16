import { enrichAllBlindSpotQualityRecords } from "@/lib/blind-spots/blind-spot-quality-enrichment";
import { hasAnyQualityOutcome } from "@/lib/blind-spots/blind-spot-quality-score";
import { readAllBlindSpotQualityRecords } from "@/lib/blind-spots/blind-spot-quality-storage";
import { buildInsightIngredientProfile, TIER_LABELS } from "@/lib/insights/insight-ingredient-optimizer";
import type { BlindSpotQualityEnrichedRecord } from "@/types/blind-spot-quality";
import type {
  InsightIngredientKey,
  InsightIngredientOptimizerMultiplier,
  InsightIngredientOptimizerReport,
  InsightIngredientOutcomeRates,
  InsightIngredientTier,
  InsightIngredientTierOutcomeRates,
  InsightOptimizerRecommendation,
} from "@/types/insight-ingredient-optimizer";

const MIN_SAMPLE_FOR_RECOMMENDATION = 8;
const LOW_SAMPLE_THRESHOLD = 5;

const INGREDIENT_LABELS: Record<InsightIngredientKey, string> = {
  contradiction: "Contradictions",
  cost_evidence: "Cost evidence",
  cross_life_area: "Cross life-area",
  failed_prediction: "Failed predictions",
};

const ALL_TIERS: InsightIngredientTier[] = ["a_tier", "b_tier", "c_tier", "d_tier"];

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function multiplier(topRate: number | null, bottomRate: number | null): number | null {
  if (topRate === null || bottomRate === null || bottomRate === 0) return null;
  if (topRate === 0) return null;
  return Math.round((topRate / bottomRate) * 10) / 10;
}

function isSuccess(outcomes: BlindSpotQualityEnrichedRecord["outcomes"]): boolean {
  return hasAnyQualityOutcome(outcomes);
}

function profileFromQualityRecord(
  record: BlindSpotQualityEnrichedRecord,
): ReturnType<typeof buildInsightIngredientProfile> {
  return buildInsightIngredientProfile({
    reviewId: record.reviewId,
    blindSpotId: record.blindSpotId,
    contradictionPresent: record.contradictionPresent,
    costEvidencePresent: record.costEvidencePresent,
    crossLifeAreaPresent: record.crossLifeAreaPresent,
    failedPredictionPresent: record.failedPredictionPresent,
    evidenceStrength: record.evidenceStrength,
    scorecardScore: record.scorecardScore,
    createdAt: record.generatedAt,
  });
}

function hasIngredient(
  record: BlindSpotQualityEnrichedRecord,
  key: InsightIngredientKey,
): boolean {
  switch (key) {
    case "contradiction":
      return record.contradictionPresent;
    case "cost_evidence":
      return record.costEvidencePresent;
    case "cross_life_area":
      return record.crossLifeAreaPresent;
    case "failed_prediction":
      return record.failedPredictionPresent;
  }
}

function buildTierOutcomeRates(
  enriched: BlindSpotQualityEnrichedRecord[],
): InsightIngredientTierOutcomeRates[] {
  return ALL_TIERS.map((tier) => {
    const rows = enriched.filter(
      (r) => profileFromQualityRecord(r).tier === tier,
    );
    const count = rows.length;
    return {
      tier,
      tierLabel: TIER_LABELS[tier],
      count,
      surprisingRate: pct(rows.filter((r) => r.outcomes.surprising).length, count),
      uncomfortablyAccurateRate: pct(
        rows.filter((r) => r.outcomes.uncomfortablyAccurate).length,
        count,
      ),
      breakthroughRate: pct(rows.filter((r) => r.outcomes.breakthrough).length, count),
      actedDifferentlyRate: pct(
        rows.filter((r) => r.outcomes.actedDifferently).length,
        count,
      ),
      problemImprovedRate: pct(
        rows.filter((r) => r.outcomes.problemImproved).length,
        count,
      ),
      overallSuccessRate: pct(rows.filter((r) => isSuccess(r.outcomes)).length, count),
    };
  });
}

function buildIngredientOutcomeRates(
  enriched: BlindSpotQualityEnrichedRecord[],
): InsightIngredientOutcomeRates[] {
  return (Object.keys(INGREDIENT_LABELS) as InsightIngredientKey[]).map((key) => {
    const present = enriched.filter((r) => hasIngredient(r, key));
    const absent = enriched.filter((r) => !hasIngredient(r, key));
    return {
      key,
      label: INGREDIENT_LABELS[key],
      presentCount: present.length,
      absentCount: absent.length,
      presentSuccessRate: pct(
        present.filter((r) => isSuccess(r.outcomes)).length,
        present.length,
      ),
      absentSuccessRate: pct(absent.filter((r) => isSuccess(r.outcomes)).length, absent.length),
    };
  });
}

function buildSuccessMultipliers(
  tierRates: InsightIngredientTierOutcomeRates[],
  ingredientRates: InsightIngredientOutcomeRates[],
): InsightIngredientOptimizerMultiplier[] {
  const aTier = tierRates.find((r) => r.tier === "a_tier");
  const dTier = tierRates.find((r) => r.tier === "d_tier");
  const bTier = tierRates.find((r) => r.tier === "b_tier");

  const multipliers: InsightIngredientOptimizerMultiplier[] = [
    {
      label: "A-tier vs D-tier",
      multiplier: multiplier(aTier?.overallSuccessRate ?? null, dTier?.overallSuccessRate ?? null),
      line: "",
    },
    {
      label: "B-tier vs D-tier",
      multiplier: multiplier(bTier?.overallSuccessRate ?? null, dTier?.overallSuccessRate ?? null),
      line: "",
    },
  ];

  for (const row of ingredientRates) {
    multipliers.push({
      label: `${row.label} present vs absent`,
      multiplier: multiplier(row.presentSuccessRate, row.absentSuccessRate),
      line: "",
    });
  }

  return multipliers.map((row) => ({
    ...row,
    line:
      row.multiplier !== null && row.multiplier >= 1.1
        ? `${row.label}: ${row.multiplier}× success rate`
        : `${row.label}: not enough contrast yet`,
  }));
}

function pickRecommendation(
  total: number,
  tierRates: InsightIngredientTierOutcomeRates[],
): { recommendation: InsightOptimizerRecommendation; line: string } {
  if (total < MIN_SAMPLE_FOR_RECOMMENDATION) {
    return {
      recommendation: "insufficient_data",
      line: "Need more blind spot quality records before changing ranking emphasis.",
    };
  }

  const aRate = tierRates.find((r) => r.tier === "a_tier")?.overallSuccessRate ?? 0;
  const bRate = tierRates.find((r) => r.tier === "b_tier")?.overallSuccessRate ?? 0;
  const dRate = tierRates.find((r) => r.tier === "d_tier")?.overallSuccessRate ?? 0;

  if (aRate > 0 && aRate >= dRate + 15) {
    return {
      recommendation: "prioritize_a_tier",
      line: "Ranking should keep favoring blind spots with 3+ high-value ingredients.",
    };
  }
  if (bRate > 0 && bRate >= dRate + 8) {
    return {
      recommendation: "prioritize_b_tier",
      line: "Two high-value ingredients still outperform empty mixes — keep B-tier boost.",
    };
  }

  return {
    recommendation: "insufficient_data",
    line: "Tier outcome contrast is still thin on this device.",
  };
}

export function buildInsightIngredientOptimizerReport(
  records = readAllBlindSpotQualityRecords(),
): InsightIngredientOptimizerReport {
  const enriched = enrichAllBlindSpotQualityRecords(records);
  const profiles = enriched.map(profileFromQualityRecord);

  const tierCounts: Record<InsightIngredientTier, number> = {
    a_tier: 0,
    b_tier: 0,
    c_tier: 0,
    d_tier: 0,
  };
  for (const profile of profiles) {
    tierCounts[profile.tier] += 1;
  }

  const tierOutcomeRates = buildTierOutcomeRates(enriched);
  const ingredientOutcomeRates = buildIngredientOutcomeRates(enriched);
  const successMultipliers = buildSuccessMultipliers(tierOutcomeRates, ingredientOutcomeRates);
  const { recommendation, line: recommendationLine } = pickRecommendation(
    enriched.length,
    tierOutcomeRates,
  );

  const lines = [
    `Profiles analyzed: ${profiles.length}`,
    `A-tier: ${tierCounts.a_tier} · B-tier: ${tierCounts.b_tier} · C-tier: ${tierCounts.c_tier} · D-tier: ${tierCounts.d_tier}`,
    recommendationLine,
    ...successMultipliers
      .filter((m) => m.multiplier !== null && m.multiplier >= 1.2)
      .slice(0, 5)
      .map((m) => m.line),
  ];

  return {
    generatedAt: new Date().toISOString(),
    totalProfiles: profiles.length,
    tierCounts,
    tierOutcomeRates,
    ingredientOutcomeRates,
    successMultipliers,
    recommendation,
    recommendationLine,
    lowSampleWarning: enriched.length < LOW_SAMPLE_THRESHOLD,
    lines,
  };
}
