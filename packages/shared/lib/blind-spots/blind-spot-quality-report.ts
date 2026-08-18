import { enrichAllBlindSpotQualityRecords } from "@/lib/blind-spots/blind-spot-quality-enrichment";
import { hasAnyQualityOutcome } from "@/lib/blind-spots/blind-spot-quality-score";
import { readAllBlindSpotReviewSnapshots } from "@/lib/blind-spots/blind-spot-review-snapshots";
import {
  qualityRecordFromSnapshot,
  readAllBlindSpotQualityRecords,
} from "@/lib/blind-spots/blind-spot-quality-storage";
import type { BlindSpotQualityRecord } from "@/types/blind-spot-quality";
import type {
  BlindSpotQualityEnrichedRecord,
  BlindSpotQualityIngredientFrequency,
  BlindSpotQualityIngredientKey,
  BlindSpotQualityRankedRow,
  BlindSpotQualityReport,
  BlindSpotQualitySuccessMultiplier,
} from "@/types/blind-spot-quality";

const INGREDIENT_DEFS: Array<{ key: BlindSpotQualityIngredientKey; label: string }> = [
  { key: "contradiction", label: "Contradictions" },
  { key: "cost_evidence", label: "Cost evidence" },
  { key: "cross_life_area", label: "Cross life-area" },
  { key: "failed_prediction", label: "Failed predictions" },
  { key: "long_span", label: "Long time span" },
  { key: "root_belief", label: "Root belief" },
];

const TOP_BOTTOM_LIMIT = 20;

function pct(count: number, total: number): number | null {
  if (total <= 0) return null;
  return Math.round((count / total) * 1000) / 10;
}

function hasIngredient(
  record: BlindSpotQualityEnrichedRecord,
  key: BlindSpotQualityIngredientKey,
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
    case "long_span":
      return record.longSpanPresent;
    case "root_belief":
      return record.rootBeliefPresent;
  }
}

function toRankedRow(record: BlindSpotQualityEnrichedRecord): BlindSpotQualityRankedRow {
  return {
    reviewId: record.reviewId,
    blindSpotId: record.blindSpotId,
    headline: record.headline,
    blindSpotQualityScore: record.blindSpotQualityScore,
    scorecardScore: record.scorecardScore,
    evidenceStrength: record.evidenceStrength,
    outcomes: record.outcomes,
    generatedAt: record.generatedAt,
  };
}

function buildIngredientFrequencies(
  records: BlindSpotQualityEnrichedRecord[],
): BlindSpotQualityIngredientFrequency[] {
  const total = records.length;
  return INGREDIENT_DEFS.map(({ key, label }) => {
    const count = records.filter((r) => hasIngredient(r, key)).length;
    return {
      key,
      label,
      count,
      frequency: pct(count, total),
    };
  });
}

function buildSuccessMultipliers(
  top: BlindSpotQualityEnrichedRecord[],
  bottom: BlindSpotQualityEnrichedRecord[],
): BlindSpotQualitySuccessMultiplier[] {
  return INGREDIENT_DEFS.map(({ key, label }) => {
    const topCount = top.filter((r) => hasIngredient(r, key)).length;
    const bottomCount = bottom.filter((r) => hasIngredient(r, key)).length;
    const topShare = pct(topCount, top.length);
    const bottomShare = pct(bottomCount, bottom.length);

    let multiplier: number | null = null;
    if (top.length > 0 && bottom.length > 0 && bottomShare !== null && topShare !== null) {
      if (bottomShare === 0) {
        multiplier = topShare > 0 ? null : null;
      } else {
        multiplier = Math.round((topShare / bottomShare) * 10) / 10;
      }
    }

    const line =
      multiplier !== null && multiplier > 1
        ? `${label}: ${multiplier}× more common in top performers`
        : multiplier !== null && multiplier < 1 && multiplier > 0
          ? `${label}: ${Math.round((1 / multiplier) * 10) / 10}× more common in weaker performers`
          : `${label}: not enough contrast yet`;

    return { key, label, multiplier, topShare, bottomShare, line };
  }).sort((a, b) => (b.multiplier ?? 0) - (a.multiplier ?? 0));
}

function mergeQualityRecordsWithSnapshots(
  stored: BlindSpotQualityRecord[],
): BlindSpotQualityRecord[] {
  const keys = new Set(stored.map((r) => `${r.reviewId}|${r.generatedAt}`));
  const backfill = readAllBlindSpotReviewSnapshots()
    .map(qualityRecordFromSnapshot)
    .filter((row) => !keys.has(`${row.reviewId}|${row.generatedAt}`));
  return [...stored, ...backfill];
}

export function buildBlindSpotQualityReport(
  records = mergeQualityRecordsWithSnapshots(readAllBlindSpotQualityRecords()),
): BlindSpotQualityReport {
  const enriched = enrichAllBlindSpotQualityRecords(records);
  const withSignal = enriched.filter((r) => hasAnyQualityOutcome(r.outcomes));
  const ranked = [...withSignal].sort(
    (a, b) =>
      b.blindSpotQualityScore - a.blindSpotQualityScore ||
      b.scorecardScore - a.scorecardScore ||
      b.generatedAt.localeCompare(a.generatedAt),
  );

  const fallbackRanked = [...enriched].sort(
    (a, b) =>
      b.scorecardScore - a.scorecardScore || b.generatedAt.localeCompare(a.generatedAt),
  );
  const sortSource = ranked.length > 0 ? ranked : fallbackRanked;

  const topPerformers = sortSource.slice(0, TOP_BOTTOM_LIMIT).map(toRankedRow);
  const bottomPool = [...sortSource].reverse();
  const bottomPerformers = bottomPool.slice(0, TOP_BOTTOM_LIMIT).map(toRankedRow);

  const topEnriched = sortSource.slice(0, TOP_BOTTOM_LIMIT);
  const bottomEnriched = bottomPool.slice(0, TOP_BOTTOM_LIMIT);

  const ingredientFrequencies = buildIngredientFrequencies(enriched);
  const successMultipliers = buildSuccessMultipliers(topEnriched, bottomEnriched);

  const lines = [
    `Quality records: ${enriched.length}`,
    `With change signals: ${withSignal.length}`,
    `Top performer avg quality score: ${
      topEnriched.length > 0
        ? Math.round(
            topEnriched.reduce((s, r) => s + r.blindSpotQualityScore, 0) / topEnriched.length,
          )
        : "—"
    }`,
    ...successMultipliers
      .filter((row) => row.multiplier !== null && row.multiplier >= 1.2)
      .slice(0, 6)
      .map((row) => row.line),
  ];

  return {
    generatedAt: new Date().toISOString(),
    totalRecords: enriched.length,
    recordsWithOutcomes: withSignal.length,
    topPerformers,
    bottomPerformers,
    ingredientFrequencies,
    successMultipliers,
    lines,
  };
}
