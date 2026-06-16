import { buildBlindSpotReview } from "@/lib/blind-spots/blind-spot-review";
import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { readAllBreakthroughEvents } from "@/lib/breakthrough/breakthrough-events";
import {
  buildInsightScorecardFromBlindSpotReview,
  buildInsightScorecardFromTheory,
  INGREDIENT_LABELS,
  sortInsightsByRecognitionLikelihood,
} from "@/lib/insights/insight-scorecard";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  InsightIngredientHitRate,
  InsightIngredientKey,
  InsightScorecard,
  InsightScorecardReport,
  InsightScorecardSurface,
  InsightScorecardSurfaceSummary,
} from "@/types/insight-scorecard";
import type { JournalEntry } from "@/types/journal";

const INGREDIENT_ORDER: InsightIngredientKey[] = [
  "cross_life_area",
  "cost_evidence",
  "contradiction",
  "long_time_span",
  "failed_prediction",
];

function average(nums: number[]): number | null {
  if (nums.length === 0) return null;
  return Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 10) / 10;
}

function pct(numerator: number, denominator: number): number | null {
  if (denominator === 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function collectScorecardsFromDevice(entries: JournalEntry[]): InsightScorecard[] {
  const cards: InsightScorecard[] = [];
  const entriesById = new Map(entries.map((e) => [e.id, e]));

  const reviewReport = buildBlindSpotReview(entries);
  if (reviewReport.kind === "ready") {
    cards.push(
      reviewReport.review.scorecard ?? buildInsightScorecardFromBlindSpotReview(reviewReport.review),
    );
  }

  const theories = buildTheoryTrackerReport(entries, { persistSnapshots: false }).all;
  for (const theory of theories) {
    cards.push(theory.scorecard ?? buildInsightScorecardFromTheory(theory, entriesById));
  }

  return cards;
}

function buildBreakthroughComparisonLines(scorecards: InsightScorecard[]): string[] {
  const yesBreakthroughs = readAllBreakthroughEvents().filter((e) => e.answer === "yes");
  const strongFeedback = readAllBlindSpotFeedback().filter(
    (f) => f.reaction === "surprising" || f.reaction === "uncomfortably_accurate",
  );

  const highCards = scorecards.filter((c) => c.score >= 60);
  const lines: string[] = [];

  if (yesBreakthroughs.length > 0 && highCards.length > 0) {
    const linked = yesBreakthroughs.filter((b) =>
      highCards.some(
        (c) =>
          c.insightId === b.relatedBlindSpotId ||
          c.insightId === b.relatedTheoryId,
      ),
    ).length;
    lines.push(
      `${linked} yes-breakthrough events overlap high-scorecard insights (${highCards.length} scored ≥60).`,
    );
  }

  if (strongFeedback.length > 0) {
    const avgHigh = average(highCards.map((c) => c.score)) ?? null;
    lines.push(
      `${strongFeedback.length} strong blind-spot reactions on device; average high-scorecard score ${avgHigh ?? "—"}.`,
    );
  }

  if (lines.length === 0) {
    lines.push("No breakthrough or strong-reaction overlap yet — scorecards ready for comparison.");
  }

  return lines;
}

export function buildInsightScorecardReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): InsightScorecardReport {
  const scorecards = collectScorecardsFromDevice(entries);
  const sorted = sortInsightsByRecognitionLikelihood(scorecards);
  const scores = scorecards.map((c) => c.score);

  const surfaces: InsightScorecardSurface[] = [
    "blind_spot",
    "theory",
    "prediction",
    "emerging_pattern",
    "discover",
  ];

  const bySurface: InsightScorecardSurfaceSummary[] = surfaces
    .map((surface) => {
      const rows = scorecards.filter((c) => c.surface === surface);
      return {
        surface,
        count: rows.length,
        averageScore: average(rows.map((r) => r.score)),
      };
    })
    .filter((row) => row.count > 0);

  const ingredientHitRates: InsightIngredientHitRate[] = INGREDIENT_ORDER.map((key) => {
    const presentCount = scorecards.filter((c) =>
      c.ingredients.find((i) => i.key === key)?.present,
    ).length;
    return {
      key,
      label: INGREDIENT_LABELS[key],
      presentCount,
      hitRate: pct(presentCount, scorecards.length),
    };
  });

  return {
    generatedAt: new Date().toISOString(),
    totalScored: scorecards.length,
    averageScore: average(scores),
    highest: sorted.slice(0, 5),
    lowest: [...sorted].reverse().slice(0, 5),
    bySurface,
    ingredientHitRates,
    recommendedPriorityOrder: sorted,
    breakthroughComparisonLines: buildBreakthroughComparisonLines(scorecards),
  };
}
