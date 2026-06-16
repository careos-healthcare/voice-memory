import { buildBlindSpotAccelerationReport } from "@/lib/blind-spots/blind-spot-acceleration";
import {
  computeEvidenceStrength,
  linkedAreasForEntries,
} from "@/lib/blind-spots/blind-spot-ranking";
import { wowMomentScoreForReaction } from "@/lib/blind-spots/wow-moment-score";
import { readAllTheoryFeedback } from "@/lib/theories/theory-feedback";
import {
  computeTheoryConfidence,
  lifeAreaCountForQuotes,
  spanDaysForQuotes,
} from "@/lib/theories/theory-confidence";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import type { BlindSpotFeedbackRecord, BlindSpotReaction } from "@/types/blind-spot";
import type { CostEvidenceCounts } from "@/types/blind-spot-acceleration";
import type {
  InsightFeedbackRow,
  InsightIngredientMetrics,
  InsightReactionTier,
  InsightSurface,
  IngredientComparisonRow,
  SelfRecognitionIngredientsReport,
} from "@/types/self-recognition-ingredients";
import type { TheoryFeedbackReaction, TheoryFeedbackRecord } from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

const STRONG_BLIND_SPOT: BlindSpotReaction[] = ["surprising", "uncomfortably_accurate"];
const WEAK_BLIND_SPOT: BlindSpotReaction[] = ["obvious", "completely_wrong"];

const STRONG_THEORY: TheoryFeedbackReaction[] = ["surprising"];
const WEAK_THEORY: TheoryFeedbackReaction[] = ["not_true", "too_obvious"];

const METRIC_LABELS: Record<keyof InsightIngredientMetrics, string> = {
  evidenceQuoteCount: "Evidence quote count",
  timeSpanDays: "Time span (days)",
  lifeAreaCount: "Life-area count",
  contradictionCount: "Contradiction count",
  predictionFailureCount: "Prediction failure count",
  costEvidenceCount: "Cost evidence count",
  rootBeliefPresent: "Root belief present",
  specificityScore: "Specificity score",
  confidenceScore: "Confidence score",
  evidenceStrength: "Evidence strength label",
  evidenceStrengthScore: "Evidence strength score",
};

const NUMERIC_METRIC_KEYS: Array<keyof InsightIngredientMetrics> = [
  "evidenceQuoteCount",
  "timeSpanDays",
  "lifeAreaCount",
  "contradictionCount",
  "predictionFailureCount",
  "costEvidenceCount",
  "rootBeliefPresent",
  "specificityScore",
  "confidenceScore",
  "evidenceStrengthScore",
];

interface CatalogEntry {
  surface: InsightSurface;
  headline: string;
  ingredients: InsightIngredientMetrics;
}

function evidenceStrengthToScore(label: InsightIngredientMetrics["evidenceStrength"]): number {
  switch (label) {
    case "very_high":
      return 92;
    case "high":
      return 76;
    case "medium":
      return 52;
    default:
      return 28;
  }
}

function sumCostEvidence(counts: CostEvidenceCounts): number {
  return Object.values(counts).reduce((sum, n) => sum + n, 0);
}

function metricsFromCostAndQuotes(input: {
  evidenceQuoteCount: number;
  timeSpanDays: number;
  lifeAreaCount: number;
  contradictionCount: number;
  predictionFailureCount: number;
  costEvidence: CostEvidenceCounts;
  rootBeliefPresent?: number;
  specificityScore?: number;
  confidenceScore: number;
  evidenceStrength: InsightIngredientMetrics["evidenceStrength"];
  evidenceStrengthScore: number;
}): InsightIngredientMetrics {
  return {
    evidenceQuoteCount: input.evidenceQuoteCount,
    timeSpanDays: input.timeSpanDays,
    lifeAreaCount: input.lifeAreaCount,
    contradictionCount: input.contradictionCount,
    predictionFailureCount: input.predictionFailureCount,
    costEvidenceCount: sumCostEvidence(input.costEvidence),
    rootBeliefPresent: input.rootBeliefPresent ?? 0,
    specificityScore: input.specificityScore ?? 0,
    confidenceScore: input.confidenceScore,
    evidenceStrength: input.evidenceStrength,
    evidenceStrengthScore: input.evidenceStrengthScore,
  };
}

function buildInsightCatalog(entries: JournalEntry[]): Map<string, CatalogEntry> {
  const catalog = new Map<string, CatalogEntry>();
  const eligible = entries.filter((e) => e.reflectionPending !== true);
  const entriesById = new Map(eligible.map((e) => [e.id, e]));
  const acceleration = buildBlindSpotAccelerationReport(eligible);

  if (acceleration.mainReview.kind === "ready") {
    const review = acceleration.mainReview.review;
    const spanDays = spanDaysForQuotes(
      review.evidenceQuotes.map((q) => ({
        entryId: q.entryId,
        dateLabel: q.dateLabel,
        quote: q.quote,
      })),
      entriesById,
    );
    catalog.set(review.reviewId, {
      surface: "blind_spot",
      headline: review.headline,
      ingredients: metricsFromCostAndQuotes({
        evidenceQuoteCount: review.evidenceQuotes.length,
        timeSpanDays: review.evidenceStrengthFacts.spanDays || spanDays,
        lifeAreaCount: review.evidenceStrengthFacts.lifeAreaCount,
        contradictionCount: review.evidenceStrengthFacts.contradictionPresent ? 1 : 0,
        predictionFailureCount: review.evidenceStrengthFacts.failedPredictionCount,
        costEvidence: review.costEvidence,
        rootBeliefPresent: review.rootBeliefHypothesis ? 1 : 0,
        specificityScore: review.specificityScore,
        confidenceScore: review.estimatedImpactScore,
        evidenceStrength: review.evidenceStrength,
        evidenceStrengthScore: evidenceStrengthToScore(review.evidenceStrength),
      }),
    });
  }

  for (const pattern of acceleration.emergingPatterns) {
    const linked = linkedAreasForEntries(
      eligible,
      pattern.evidenceQuotes.map((q) => q.entryId),
    );
    const spanDays = spanDaysForQuotes(
      pattern.evidenceQuotes.map((q) => ({
        entryId: q.entryId,
        dateLabel: q.dateLabel,
        quote: q.quote,
      })),
      entriesById,
    );
    const { score, label } = computeEvidenceStrength({
      matchingReflections: pattern.matchingReflections,
      spanDays,
      lifeAreaCount: linked.length,
      signalBonus: pattern.id.includes("contradiction") ? 8 : 0,
    });

    catalog.set(pattern.id, {
      surface: "emerging",
      headline: pattern.hypothesis.slice(0, 120),
      ingredients: metricsFromCostAndQuotes({
        evidenceQuoteCount: pattern.evidenceQuotes.length,
        timeSpanDays: spanDays,
        lifeAreaCount: linked.length,
        contradictionCount: pattern.id.includes("contradiction") ? 1 : 0,
        predictionFailureCount: 0,
        costEvidence: {
          avoidance: 0,
          delayedDecisions: 0,
          quittingLanguage: 0,
          repeatedConflict: 0,
          emotionalSpirals: 0,
        },
        confidenceScore: Math.round(score * 0.45),
        evidenceStrength: label,
        evidenceStrengthScore: score,
      }),
    });
  }

  for (const item of acceleration.predictionReview.items) {
    const failureTone = /\b(fail|failure|mess up|fall apart|go wrong)\b/i.test(
      item.candidate.quote,
    );
    const predictionFailureCount =
      item.outcomeStatus === "diverged" && item.candidate.polarity === "negative"
        ? 1
        : item.outcomeStatus === "aligned" && failureTone
          ? 1
          : 0;

    catalog.set(item.candidate.id, {
      surface: "prediction",
      headline: item.candidate.quote.slice(0, 120),
      ingredients: metricsFromCostAndQuotes({
        evidenceQuoteCount: item.laterEvidence ? 2 : 1,
        timeSpanDays: item.laterEvidence ? 14 : 0,
        lifeAreaCount: 1,
        contradictionCount: 0,
        predictionFailureCount,
        costEvidence: {
          avoidance: 0,
          delayedDecisions: 0,
          quittingLanguage: 0,
          repeatedConflict: 0,
          emotionalSpirals: 0,
        },
        confidenceScore: item.outcomeStatus === "aligned" ? 72 : 38,
        evidenceStrength: item.laterEvidence ? "medium" : "low",
        evidenceStrengthScore: item.laterEvidence ? 55 : 30,
      }),
    });
  }

  const theories = buildTheoryTrackerReport(eligible, { persistSnapshots: false });
  for (const theory of theories.all) {
    const spanDays = spanDaysForQuotes(theory.supportingEvidence, entriesById);
    const lifeAreaCount = lifeAreaCountForQuotes(theory.supportingEvidence, eligible);
    const strengthLabel =
      theory.confidence >= 70
        ? "high"
        : theory.confidence >= 50
          ? "medium"
          : "low";

    catalog.set(theory.id, {
      surface: "theory",
      headline: theory.statement.slice(0, 120),
      ingredients: metricsFromCostAndQuotes({
        evidenceQuoteCount:
          theory.supportingEvidence.length + theory.contradictingEvidence.length,
        timeSpanDays: spanDays,
        lifeAreaCount,
        contradictionCount: theory.contradictingEvidenceCount,
        predictionFailureCount: theory.source === "prediction" ? 1 : 0,
        costEvidence: {
          avoidance: 0,
          delayedDecisions: 0,
          quittingLanguage: 0,
          repeatedConflict: 0,
          emotionalSpirals: 0,
        },
        rootBeliefPresent: theory.rootBeliefHypothesis ? 1 : 0,
        specificityScore: theory.confidence,
        confidenceScore: theory.confidence,
        evidenceStrength: strengthLabel,
        evidenceStrengthScore: computeTheoryConfidence({
          supportingCount: theory.supportingEvidenceCount,
          contradictingCount: theory.contradictingEvidenceCount,
          spanDays,
          lifeAreaCount,
        }),
      }),
    });
  }

  return catalog;
}

function fallbackFromBlindSpotFeedback(
  record: BlindSpotFeedbackRecord,
): InsightIngredientMetrics {
  return {
    evidenceQuoteCount: Math.max(2, Math.min(record.reflectionCount, 8)),
    timeSpanDays: record.archiveAgeDays,
    lifeAreaCount: Math.min(3, Math.max(1, Math.round(record.reflectionCount / 3))),
    contradictionCount: record.patternType === "contradiction" ? 1 : 0,
    predictionFailureCount: 0,
    costEvidenceCount: 0,
    rootBeliefPresent: 0,
    specificityScore: 0,
    confidenceScore: record.estimatedImpactScore,
    evidenceStrength: record.evidenceStrength,
    evidenceStrengthScore: evidenceStrengthToScore(record.evidenceStrength),
  };
}

function blindSpotTier(reaction: BlindSpotReaction): InsightReactionTier {
  if (STRONG_BLIND_SPOT.includes(reaction)) return "strong";
  if (WEAK_BLIND_SPOT.includes(reaction)) return "weak";
  return "neutral";
}

function theoryTier(reaction: TheoryFeedbackReaction): InsightReactionTier {
  if (STRONG_THEORY.includes(reaction)) return "strong";
  if (WEAK_THEORY.includes(reaction)) return "weak";
  return "neutral";
}

function theoryWowScore(reaction: TheoryFeedbackReaction): number {
  switch (reaction) {
    case "surprising":
      return 2;
    case "feels_true":
      return 1;
    case "partly_true":
      return 0;
    case "too_obvious":
      return -1;
    case "not_true":
      return -2;
    default:
      return 0;
  }
}

function resolveReferenceId(record: BlindSpotFeedbackRecord): string {
  if (record.reviewId.startsWith("emerging:")) return record.reviewId;
  if (record.reviewId.startsWith("prediction:")) return record.reviewId.replace(/^prediction:/, "");
  return record.reviewId;
}

function surfaceForReviewId(reviewId: string): InsightSurface {
  if (reviewId.startsWith("emerging:")) return "emerging";
  if (reviewId.startsWith("prediction:") || reviewId.startsWith("pred:")) return "prediction";
  if (reviewId.startsWith("theory:")) return "theory";
  return "blind_spot";
}

function collectBlindSpotRows(
  records: BlindSpotFeedbackRecord[],
  catalog: Map<string, CatalogEntry>,
): InsightFeedbackRow[] {
  return records.map((record) => {
    const ref = resolveReferenceId(record);
    const entry = catalog.get(ref) ?? catalog.get(record.reviewId);
    const surface = entry?.surface ?? surfaceForReviewId(record.reviewId);
    const ingredients = entry?.ingredients ?? fallbackFromBlindSpotFeedback(record);

    return {
      id: record.id,
      surface,
      referenceId: ref,
      headline: entry?.headline ?? record.headline,
      reaction: record.reaction,
      reactionTier: blindSpotTier(record.reaction),
      wowScore: wowMomentScoreForReaction(record.reaction),
      ingredients,
      at: record.at,
    };
  });
}

function collectTheoryRows(
  records: TheoryFeedbackRecord[],
  catalog: Map<string, CatalogEntry>,
): InsightFeedbackRow[] {
  return records.map((record) => {
    const entry = catalog.get(record.theoryId);
    const ingredients =
      entry?.ingredients ??
      metricsFromCostAndQuotes({
        evidenceQuoteCount: 2,
        timeSpanDays: 0,
        lifeAreaCount: 1,
        contradictionCount: 0,
        predictionFailureCount: record.source === "prediction" ? 1 : 0,
        costEvidence: {
          avoidance: 0,
          delayedDecisions: 0,
          quittingLanguage: 0,
          repeatedConflict: 0,
          emotionalSpirals: 0,
        },
        rootBeliefPresent: 0,
        specificityScore: 0,
        confidenceScore: record.confidence,
        evidenceStrength:
          record.confidence >= 60 ? "medium" : ("low" as InsightIngredientMetrics["evidenceStrength"]),
        evidenceStrengthScore: record.confidence,
      });

    return {
      id: record.id,
      surface: entry?.surface ?? (record.source === "emerging" ? "emerging" : record.source === "prediction" ? "prediction" : "theory"),
      referenceId: record.theoryId,
      headline: entry?.headline ?? record.statement.slice(0, 120),
      reaction: record.reaction,
      reactionTier: theoryTier(record.reaction),
      wowScore: theoryWowScore(record.reaction),
      ingredients,
      at: record.at,
    };
  });
}

function averageMetric(
  rows: InsightFeedbackRow[],
  key: keyof InsightIngredientMetrics,
): number | null {
  if (rows.length === 0) return null;
  const sum = rows.reduce((acc, row) => acc + Number(row.ingredients[key]), 0);
  return Math.round((sum / rows.length) * 10) / 10;
}

function buildIngredientComparisons(
  strong: InsightFeedbackRow[],
  weak: InsightFeedbackRow[],
): IngredientComparisonRow[] {
  return NUMERIC_METRIC_KEYS.map((key) => {
    const strongAverage = averageMetric(strong, key);
    const weakAverage = averageMetric(weak, key);
    const delta =
      strongAverage !== null && weakAverage !== null
        ? Math.round((strongAverage - weakAverage) * 10) / 10
        : null;
    return {
      key,
      label: METRIC_LABELS[key],
      strongAverage,
      weakAverage,
      delta,
    };
  }).sort((a, b) => Math.abs(b.delta ?? 0) - Math.abs(a.delta ?? 0));
}

function ingredientLine(row: IngredientComparisonRow, favor: "strong" | "weak"): string | null {
  if (row.delta === null || row.strongAverage === null || row.weakAverage === null) {
    return null;
  }
  const threshold = 0.5;
  if (favor === "strong" && row.delta <= threshold) return null;
  if (favor === "weak" && row.delta >= -threshold) return null;

  const higher = row.delta > 0 ? "strong" : "weak";
  if (favor === "strong" && higher !== "strong") return null;
  if (favor === "weak" && higher !== "weak") return null;

  return `${row.label}: ${favor === "strong" ? row.strongAverage : row.weakAverage} avg vs ${favor === "strong" ? row.weakAverage : row.strongAverage} (${favor === "strong" ? "+" : ""}${row.delta})`;
}

function buildAccuracyCorrelationLines(
  comparisons: IngredientComparisonRow[],
): string[] {
  const priorityKeys: Array<keyof InsightIngredientMetrics> = [
    "specificityScore",
    "contradictionCount",
    "predictionFailureCount",
    "timeSpanDays",
    "lifeAreaCount",
    "costEvidenceCount",
    "rootBeliefPresent",
    "evidenceStrengthScore",
  ];

  const lines = comparisons
    .filter((row) => priorityKeys.includes(row.key))
    .filter((row) => row.delta !== null && Math.abs(row.delta ?? 0) >= 0.5)
    .sort((a, b) => Math.abs(b.delta ?? 0) - Math.abs(a.delta ?? 0))
    .slice(0, 6)
    .map((row) => {
      if (row.delta === null || row.strongAverage === null || row.weakAverage === null) {
        return null;
      }
      const direction = row.delta > 0 ? "higher" : "lower";
      return `${row.label} tends ${direction} for Surprising / Uncomfortably Accurate (${row.strongAverage} vs ${row.weakAverage}, Δ${row.delta > 0 ? "+" : ""}${row.delta}).`;
    })
    .filter((line): line is string => Boolean(line));

  return lines.length > 0
    ? lines
    : ["Not enough reaction contrast yet to correlate accuracy ingredients."];
}

function buildCommonIngredients(
  comparisons: IngredientComparisonRow[],
  favor: "strong" | "weak",
): string[] {
  const lines = comparisons
    .map((row) => ingredientLine(row, favor))
    .filter((line): line is string => Boolean(line));
  if (lines.length > 0) return lines.slice(0, 5);

  const fallback = comparisons
    .filter((row) => row.delta !== null)
    .slice(0, 3)
    .map((row) => {
      if (favor === "strong" && (row.delta ?? 0) > 0) {
        return `Strong reactions skew higher on ${row.label.toLowerCase()}.`;
      }
      if (favor === "weak" && (row.delta ?? 0) < 0) {
        return `Weak reactions skew higher on ${row.label.toLowerCase()}.`;
      }
      return null;
    })
    .filter((line): line is string => Boolean(line));

  return fallback.length > 0
    ? fallback
    : [`Not enough ${favor} reactions yet to compare ingredient mixes.`];
}

/** Strongest vs weakest insight analysis across blind spot, theory, emerging, and prediction feedback. */
export function buildSelfRecognitionIngredientsReport(
  entries: JournalEntry[],
  options?: {
    blindSpotFeedback?: BlindSpotFeedbackRecord[];
    theoryFeedback?: TheoryFeedbackRecord[];
  },
): SelfRecognitionIngredientsReport {
  const catalog = buildInsightCatalog(entries);
  const blindSpotFeedback = options?.blindSpotFeedback ?? readAllBlindSpotFeedback();
  const theoryFeedback = options?.theoryFeedback ?? readAllTheoryFeedback();

  const rows = [
    ...collectBlindSpotRows(blindSpotFeedback, catalog),
    ...collectTheoryRows(theoryFeedback, catalog),
  ];

  const strong = rows.filter((r) => r.reactionTier === "strong");
  const weak = rows.filter((r) => r.reactionTier === "weak");
  const neutral = rows.filter((r) => r.reactionTier === "neutral");

  const comparisons = buildIngredientComparisons(strong, weak);

  const surfaces: InsightSurface[] = ["blind_spot", "theory", "emerging", "prediction"];
  const bySurface = surfaces.map((surface) => ({
    surface,
    strongCount: strong.filter((r) => r.surface === surface).length,
    weakCount: weak.filter((r) => r.surface === surface).length,
  }));

  return {
    generatedAt: new Date().toISOString(),
    strongReactionCount: strong.length,
    weakReactionCount: weak.length,
    neutralReactionCount: neutral.length,
    strongestInsights: [...strong]
      .sort((a, b) => b.wowScore - a.wowScore)
      .slice(0, 8),
    weakestInsights: [...weak]
      .sort((a, b) => a.wowScore - b.wowScore)
      .slice(0, 8),
    ingredientComparisons: comparisons,
    commonStrongIngredients: buildCommonIngredients(comparisons, "strong"),
    commonWeakIngredients: buildCommonIngredients(comparisons, "weak"),
    accuracyCorrelationLines: buildAccuracyCorrelationLines(comparisons),
    bySurface,
  };
}

export function countCostEvidenceInMetrics(metrics: InsightIngredientMetrics): boolean {
  return metrics.costEvidenceCount > 0;
}
