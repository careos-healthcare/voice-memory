import { INGREDIENT_REPORT_LABELS } from "@/lib/insights/insight-outcome-copy";
import {
  profileKeyForEvent,
  profileLabelForEvent,
} from "@/lib/insights/insight-outcome-attribution";
import { readInsightOutcomeEventsWithResponse } from "@/lib/insights/insight-outcome-storage";
import type {
  InsightOutcomeEvent,
  InsightOutcomeFunnelStep,
  InsightOutcomeIngredient,
  InsightOutcomeIngredientRow,
  InsightOutcomeProfileRow,
  InsightOutcomeReport,
  InsightOutcomeResponse,
} from "@/types/insight-outcome";

const IMPROVEMENT_OUTCOMES: InsightOutcomeResponse[] = [
  "noticed_pattern",
  "caught_it_earlier",
  "acted_differently",
  "problem_improved",
];

const SUCCESS_OUTCOMES: InsightOutcomeResponse[] = [
  "acted_differently",
  "problem_improved",
];

const INGREDIENT_KEYS: InsightOutcomeIngredient[] = [
  "contradiction",
  "cost_evidence",
  "cross_life_area",
  "failed_prediction",
  "long_span",
];

const FUNNEL_LABELS: Record<InsightOutcomeResponse, string> = {
  no_change: "Nothing changed",
  noticed_pattern: "Noticed again",
  caught_it_earlier: "Caught earlier",
  acted_differently: "Acted differently",
  problem_improved: "Situation improved",
  theory_stopped_fitting: "Theory no longer fits",
};

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function hasIngredient(
  event: InsightOutcomeEvent,
  ingredient: InsightOutcomeIngredient,
): boolean {
  switch (ingredient) {
    case "contradiction":
      return event.contradictionPresent;
    case "cost_evidence":
      return event.costEvidencePresent;
    case "cross_life_area":
      return event.crossLifeAreaPresent;
    case "failed_prediction":
      return event.failedPredictionPresent;
    case "long_span":
      return event.longSpanPresent;
  }
}

function isImprovement(outcome: InsightOutcomeResponse): boolean {
  return IMPROVEMENT_OUTCOMES.includes(outcome);
}

function isSuccess(outcome: InsightOutcomeResponse): boolean {
  return SUCCESS_OUTCOMES.includes(outcome);
}

function rateForOutcome(
  events: InsightOutcomeEvent[],
  outcome: InsightOutcomeResponse,
): number | null {
  return pct(
    events.filter((e) => e.outcome === outcome).length,
    events.length,
  );
}

function buildIngredientRows(events: InsightOutcomeEvent[]): InsightOutcomeIngredientRow[] {
  return INGREDIENT_KEYS.map((ingredient) => {
    const tagged = events.filter((e) => hasIngredient(e, ingredient));
    const improved = tagged.filter((e) => e.outcome && isImprovement(e.outcome));
    return {
      ingredient,
      label: INGREDIENT_REPORT_LABELS[ingredient],
      appearances: tagged.length,
      improvementCount: improved.length,
      improvementRate: pct(improved.length, tagged.length),
    };
  });
}

function buildProfileRows(
  events: InsightOutcomeEvent[],
  mode: "top" | "weak",
): InsightOutcomeProfileRow[] {
  const map = new Map<
    string,
    { label: string; appearances: number; success: number; insightType: InsightOutcomeEvent["insightType"] }
  >();

  for (const event of events) {
    const key = profileKeyForEvent(event);
    const row = map.get(key) ?? {
      label: profileLabelForEvent(event),
      appearances: 0,
      success: 0,
      insightType: event.insightType,
    };
    row.appearances += 1;
    if (event.outcome && isSuccess(event.outcome)) row.success += 1;
    map.set(key, row);
  }

  const ranked = [...map.entries()]
    .map(([profileKey, row]) => ({
      profileKey,
      label: row.label,
      appearances: row.appearances,
      successCount: row.success,
      successRate: pct(row.success, row.appearances),
      insightType: row.insightType,
    }))
    .filter((r) => r.appearances >= 1);

  ranked.sort((a, b) => {
    const rateA = a.successRate ?? -1;
    const rateB = b.successRate ?? -1;
    if (mode === "top") {
      if (rateB !== rateA) return rateB - rateA;
      return b.successCount - a.successCount;
    }
    if (rateA !== rateB) return rateA - rateB;
    return a.appearances - b.appearances;
  });

  return ranked.slice(0, 10);
}

function buildFunnel(events: InsightOutcomeEvent[]): InsightOutcomeFunnelStep[] {
  const total = events.length;
  const order: InsightOutcomeResponse[] = [
    "no_change",
    "noticed_pattern",
    "caught_it_earlier",
    "acted_differently",
    "problem_improved",
    "theory_stopped_fitting",
  ];
  return order.map((outcome) => {
    const count = events.filter((e) => e.outcome === outcome).length;
    return {
      outcome,
      label: FUNNEL_LABELS[outcome],
      count,
      share: pct(count, total),
    };
  });
}

export function buildInsightOutcomeReport(): InsightOutcomeReport {
  const events = readInsightOutcomeEventsWithResponse();
  const total = events.length;
  const improved = events.filter((e) => e.outcome && isImprovement(e.outcome));

  const lines = [
    `Total outcome responses: ${total}`,
    `Overall improvement rate: ${pct(improved.length, total) ?? "—"}%`,
    `Acted differently: ${rateForOutcome(events, "acted_differently") ?? "—"}%`,
    `Problem improved: ${rateForOutcome(events, "problem_improved") ?? "—"}%`,
  ];

  return {
    generatedAt: new Date().toISOString(),
    totalResponses: total,
    overallOutcomeRate: pct(improved.length, total),
    noticedPatternRate: rateForOutcome(events, "noticed_pattern"),
    caughtEarlierRate: rateForOutcome(events, "caught_it_earlier"),
    actedDifferentlyRate: rateForOutcome(events, "acted_differently"),
    problemImprovedRate: rateForOutcome(events, "problem_improved"),
    theoryStoppedFittingRate: rateForOutcome(events, "theory_stopped_fitting"),
    noChangeRate: rateForOutcome(events, "no_change"),
    funnel: buildFunnel(events),
    byIngredient: buildIngredientRows(events),
    topProfiles: buildProfileRows(events, "top"),
    weakestProfiles: buildProfileRows(events, "weak"),
    winningInsightTitle: "What actually changes behavior?",
    lines,
  };
}
