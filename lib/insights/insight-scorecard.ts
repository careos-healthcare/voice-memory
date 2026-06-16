import {
  lifeAreaCountForQuotes,
  spanDaysForQuotes,
} from "@/lib/theories/theory-confidence";
import type {
  InsightIngredientKey,
  InsightScorecard,
  InsightScorecardIngredient,
  InsightScorecardSurface,
  InsightScoreLabel,
} from "@/types/insight-scorecard";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import { formatEvidenceSpan } from "@/lib/blind-spots/blind-spot-ranking";
import type { RankedBlindSpotCandidate } from "@/lib/blind-spots/blind-spot-ranking";

export const RECOGNITION_PRIORS: Record<InsightIngredientKey, number> = {
  cross_life_area: 52,
  contradiction: 47,
  cost_evidence: 45,
  long_time_span: 22,
  failed_prediction: 14,
};

const PRIOR_TOTAL = Object.values(RECOGNITION_PRIORS).reduce((sum, n) => sum + n, 0);

const INGREDIENT_ORDER: InsightIngredientKey[] = [
  "cross_life_area",
  "cost_evidence",
  "contradiction",
  "long_time_span",
  "failed_prediction",
];

export const INGREDIENT_LABELS: Record<InsightIngredientKey, string> = {
  cross_life_area: "Appears across life areas",
  cost_evidence: "Has possible cost evidence",
  contradiction: "Contains contradiction",
  long_time_span: "Returned over 90+ days",
  failed_prediction: "Includes failed prediction evidence",
};

const HIGH_VALUE_KEYS = new Set<InsightIngredientKey>([
  "cross_life_area",
  "contradiction",
  "cost_evidence",
]);

const FORBIDDEN_SCORECARD_COPY =
  /\b(diagnos|disorder|therapy|trauma|clinical|patholog|guaranteed|certainly|the truth|fix you|cure you)\b/i;

export const SCORECARD_HELPER_COPY =
  "This is not a certainty score. It estimates whether this insight has the ingredients that have led to stronger self-recognition before.";

export interface InsightScorecardIngredientInput {
  contradiction?: boolean;
  costEvidence?: boolean;
  crossLifeArea?: boolean;
  longTimeSpanDays?: number;
  failedPrediction?: boolean;
}

export interface BuildInsightScorecardInput {
  insightId: string;
  surface: InsightScorecardSurface;
  headline: string;
  sourceIds: string[];
  ingredients: InsightScorecardIngredientInput;
  evidenceLines?: Partial<Record<InsightIngredientKey, string>>;
  createdAt?: string;
}

function sanitizeScorecardText(text: string): string {
  if (FORBIDDEN_SCORECARD_COPY.test(text)) {
    return "May be worth revisiting in your own words.";
  }
  return text;
}

export function scoreLabelForScore(score: number): InsightScoreLabel {
  if (score >= 80) return "very_high";
  if (score >= 60) return "high";
  if (score >= 40) return "medium";
  return "low";
}

export function scoreInsightIngredients(
  input: InsightScorecardIngredientInput,
  evidenceLines?: Partial<Record<InsightIngredientKey, string>>,
): InsightScorecardIngredient[] {
  const longSpanPresent = (input.longTimeSpanDays ?? 0) >= 90;

  const presentByKey: Record<InsightIngredientKey, boolean> = {
    contradiction: Boolean(input.contradiction),
    cost_evidence: Boolean(input.costEvidence),
    cross_life_area: Boolean(input.crossLifeArea),
    long_time_span: longSpanPresent,
    failed_prediction: Boolean(input.failedPrediction),
  };

  return INGREDIENT_ORDER.map((key) => ({
    key,
    label: INGREDIENT_LABELS[key],
    present: presentByKey[key],
    recognitionPrior: RECOGNITION_PRIORS[key],
    evidenceLine: evidenceLines?.[key],
  }));
}

export function calculateRecognitionLikelihoodScore(
  ingredients: InsightScorecardIngredient[],
): number {
  const presentSum = ingredients
    .filter((row) => row.present)
    .reduce((sum, row) => sum + row.recognitionPrior, 0);

  let score = Math.round((presentSum / PRIOR_TOTAL) * 100);

  const hasHighValue = ingredients.some(
    (row) => row.present && HIGH_VALUE_KEYS.has(row.key),
  );
  if (!hasHighValue) {
    score = Math.min(score, 34);
  }

  return Math.max(0, Math.min(100, score));
}

export function buildInsightScorecard(input: BuildInsightScorecardInput): InsightScorecard {
  const ingredients = scoreInsightIngredients(input.ingredients, input.evidenceLines);
  const score = calculateRecognitionLikelihoodScore(ingredients);
  const present = ingredients.filter((row) => row.present);
  const missing = ingredients.filter((row) => !row.present);
  const strongest = [...present].sort((a, b) => b.recognitionPrior - a.recognitionPrior);

  return {
    insightId: input.insightId,
    surface: input.surface,
    headline: sanitizeScorecardText(input.headline),
    score,
    scoreLabel: scoreLabelForScore(score),
    ingredients,
    missingIngredients: missing,
    strongestIngredients: strongest.slice(0, 3),
    createdAt: input.createdAt ?? new Date().toISOString(),
    sourceIds: input.sourceIds,
  };
}

/** Small tie-break boost after evidence gates — does not override impact score. */
export function scorecardTieBreakBoost(score: number): number {
  return Math.round(score * 0.12);
}

export function buildInsightScorecardFromBlindSpotCandidate(
  candidate: RankedBlindSpotCandidate,
  headline: string,
): InsightScorecard {
  const { insight } = candidate;
  return buildInsightScorecard({
    insightId: `blind-spot:${insight.type}:${insight.sourceKey}`,
    surface: "blind_spot",
    headline,
    sourceIds: insight.entryIds,
    ingredients: {
      contradiction: candidate.contradictionPresent || insight.type === "contradiction",
      costEvidence: candidate.costEvidenceCount > 0,
      crossLifeArea: candidate.lifeAreaCount >= 2,
      longTimeSpanDays: candidate.spanDays,
      failedPrediction: candidate.failedPredictionLinked,
    },
    evidenceLines: {
      long_time_span: formatEvidenceSpan(
        candidate.temporalSpread.firstDayKey,
        candidate.temporalSpread.lastDayKey,
      ),
      failed_prediction: candidate.failedPredictionLinked
        ? "Linked to a prediction that diverged from later reflections"
        : undefined,
      contradiction: candidate.contradictionPresent
        ? "Pattern type or notes suggest competing stories"
        : undefined,
    },
  });
}

export function buildInsightScorecardFromBlindSpotReview(
  review: BlindSpotReviewResult,
): InsightScorecard {
  const facts = review.evidenceStrengthFacts;
  return buildInsightScorecard({
    insightId: review.reviewId,
    surface: "blind_spot",
    headline: review.headline,
    sourceIds: review.evidenceQuotes.map((q) => q.entryId),
    ingredients: {
      contradiction: facts.contradictionPresent || Boolean(review.contradictionNote),
      costEvidence: facts.costEvidenceCount > 0 || review.costEvidenceLines.length > 0,
      crossLifeArea: facts.lifeAreaCount >= 2 || review.linkedAreas.length >= 2,
      longTimeSpanDays: facts.spanDays,
      failedPrediction: facts.failedPredictionCount > 0 || Boolean(review.predictionEvidenceNote),
    },
    evidenceLines: {
      long_time_span: facts.richSpanLabel,
      cost_evidence: review.costEvidenceLines[0],
      contradiction: review.contradictionNote,
      failed_prediction: review.predictionEvidenceNote,
    },
  });
}

export function buildInsightScorecardFromTheory(
  theory: Theory,
  entriesById: Map<string, JournalEntry>,
): InsightScorecard {
  const allQuotes = [...theory.supportingEvidence, ...theory.contradictingEvidence];
  const spanDays = spanDaysForQuotes(allQuotes, entriesById);
  const lifeAreas = lifeAreaCountForQuotes(allQuotes, [...entriesById.values()]);

  const surface: InsightScorecardSurface =
    theory.source === "prediction"
      ? "prediction"
      : theory.source === "emerging"
        ? "emerging_pattern"
        : "theory";

  const failedPrediction =
    theory.source === "prediction" && theory.contradictingEvidenceCount > 0;

  return buildInsightScorecard({
    insightId: theory.id,
    surface,
    headline: theory.statement,
    sourceIds: allQuotes.map((q) => q.entryId),
    ingredients: {
      contradiction: theory.contradictingEvidenceCount > 0,
      costEvidence: theory.whatChanged.some((line) => /cost|expensive|price/i.test(line)),
      crossLifeArea: lifeAreas >= 2,
      longTimeSpanDays: spanDays,
      failedPrediction,
    },
  });
}

export function sortInsightsByRecognitionLikelihood(
  scorecards: InsightScorecard[],
): InsightScorecard[] {
  return [...scorecards].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return b.strongestIngredients.length - a.strongestIngredients.length;
  });
}

