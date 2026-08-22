import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  analyzeEntryTemporalSpread,
  buildDivergedPredictionEntryIds,
  buildEvidenceStrengthFacts,
  computeSpecificityScore,
  insightOverlapsFailedPrediction,
  passesSkepticEvidenceGate,
  skepticCriteriaForInsight,
  temporalSpreadScoreBonus,
  totalUncomfortableAccurateBoost,
  uncomfortableAccurateImpactBoost,
} from "@/lib/blind-spots/evidence-accuracy";
import { buildCostEvidence, hasCostEvidence } from "@/lib/blind-spots/cost-evidence";
import { blindSpotPrioritizationScore } from "@/lib/blind-spots/a-tier-prioritization";
import { buildInsightIngredientProfileFromCandidate } from "@/lib/insights/insight-ingredient-optimizer";
import { buildInsightScorecardFromBlindSpotCandidate } from "@/lib/insights/insight-scorecard";
import type { PatternInsight, PatternInsightType } from "@/lib/patterns/pattern-engine";
import type { EvidenceStrengthLabel, EvidenceStrengthFacts } from "@/types/blind-spot";
import type { JournalEntry } from "@/types/journal";

export const LIFE_AREA_LABELS = [
  "Work",
  "Relationships",
  "Confidence",
  "Money",
  "Family",
  "Health",
  "Identity",
] as const;

export type LifeAreaLabel = (typeof LIFE_AREA_LABELS)[number];

const BLIND_SPOT_TYPES = new Set<PatternInsightType>([
  "contradiction",
  "avoidance_signal",
  "repeated_phrase",
  "recurring_pattern",
]);

const LIFE_AREA_KEYWORDS: Record<LifeAreaLabel, RegExp[]> = {
  Work: [/\bwork\b/i, /\bjob\b/i, /\bcareer\b/i, /\bboss\b/i, /\bmanager\b/i, /\boffice\b/i],
  Relationships: [
    /\bpartner\b/i,
    /\bboyfriend\b/i,
    /\bgirlfriend\b/i,
    /\bwife\b/i,
    /\bhusband\b/i,
    /\bfriend\b/i,
    /\brelationship\b/i,
    /\bdating\b/i,
  ],
  Confidence: [
    /\bconfidence\b/i,
    /\bnot good enough\b/i,
    /\bimpostor\b/i,
    /\bself[- ]?worth\b/i,
    /\bcompare\b/i,
    /\bafraid to\b/i,
  ],
  Money: [/\bmoney\b/i, /\bpay\b/i, /\bbill\b/i, /\bdebt\b/i, /\bafford\b/i, /\bsalary\b/i],
  Family: [/\bfamily\b/i, /\bmom\b/i, /\bdad\b/i, /\bparent\b/i, /\bsibling\b/i, /\bkid\b/i],
  Health: [/\bhealth\b/i, /\bsleep\b/i, /\banxious\b/i, /\bstress\b/i, /\bburnout\b/i],
  Identity: [/\bwho i am\b/i, /\bidentity\b/i, /\bmyself\b/i, /\bnever change\b/i],
};

const IMPACT_SIGNALS: Array<{ id: string; re: RegExp; weight: number }> = [
  { id: "avoidance", re: /\bavoid|circumvent|put off|delay|stall|indirect\b/i, weight: 25 },
  { id: "conflict", re: /\bconflict|fight|argue|tension|pulls\b/i, weight: 20 },
  { id: "delayed_decision", re: /\bkeep waiting|eventually|monday|should have|not yet\b/i, weight: 18 },
  {
    id: "quitting_escape",
    re: /\bquit|give up|escape|run away|walk away|leave it all\b/i,
    weight: 22,
  },
  {
    id: "self_worth_collapse",
    re: /\bworthless|failure|always mess|not good enough|i'?m such a|i am always\b/i,
    weight: 20,
  },
  {
    id: "wrong_prediction",
    re: /\bsaid i would|thought i would|never did|didn'?t happen|wrong again\b/i,
    weight: 15,
  },
  {
    id: "emotional_spiral",
    re: /\bspiral|overwhelm|drowning|can'?t stop|snowball|panic loop\b/i,
    weight: 18,
  },
];

const TYPE_IMPACT_BASE: Partial<Record<PatternInsightType, number>> = {
  avoidance_signal: 28,
  contradiction: 30,
  repeated_phrase: 16,
  recurring_pattern: 10,
};

const MIN_SHOW_EVIDENCE_SCORE = 55;
const MIN_MATCHING_REFLECTIONS = 3;
const MIN_EVIDENCE_QUOTES = 2;
const MIN_SPAN_DAYS = 7;

export function formatEvidenceSpan(firstKey: string, lastKey: string): string {
  const days = Math.max(0, daysBetweenKeys(firstKey, lastKey));
  if (days === 0) return "same day";
  if (days < 14) return `${days} days`;
  if (days < 60) {
    const weeks = Math.max(1, Math.round(days / 7));
    return `${weeks} week${weeks === 1 ? "" : "s"}`;
  }
  const months = Math.max(1, Math.round(days / 30));
  return `${months} month${months === 1 ? "" : "s"}`;
}

export function detectLifeAreas(text: string): LifeAreaLabel[] {
  const hits: LifeAreaLabel[] = [];
  for (const label of LIFE_AREA_LABELS) {
    if (LIFE_AREA_KEYWORDS[label].some((re) => re.test(text))) {
      hits.push(label);
    }
  }
  return hits;
}

export function linkedAreasForEntries(
  entries: JournalEntry[],
  entryIds: string[],
): LifeAreaLabel[] {
  const idSet = new Set(entryIds);
  const areas = new Set<LifeAreaLabel>();
  for (const entry of entries) {
    if (!idSet.has(entry.id)) continue;
    const blob = [
      entry.transcript,
      entry.reflection.recurringThemes.join(" "),
      entry.reflection.repeatedSignal ?? "",
      entry.reflection.concreteObservation ?? "",
    ].join(" ");
    for (const area of detectLifeAreas(blob)) {
      areas.add(area);
    }
  }
  return [...areas].slice(0, 5);
}

export function scoreImpactSignals(text: string): { score: number; signalIds: string[] } {
  let score = 0;
  const signalIds: string[] = [];
  for (const signal of IMPACT_SIGNALS) {
    if (signal.re.test(text)) {
      score += signal.weight;
      signalIds.push(signal.id);
    }
  }
  return { score, signalIds };
}

export function computeEvidenceStrength(input: {
  matchingReflections: number;
  spanDays: number;
  lifeAreaCount: number;
  signalBonus: number;
  temporalBonus?: number;
}): { score: number; label: EvidenceStrengthLabel } {
  let score = 0;
  const { matchingReflections, spanDays, lifeAreaCount, signalBonus, temporalBonus = 0 } = input;

  if (matchingReflections >= 3) score += 22;
  if (matchingReflections >= 4) score += 12;
  if (matchingReflections >= 5) score += 8;

  if (spanDays >= 7) score += 16;
  if (spanDays >= 21) score += 12;
  if (spanDays >= 30) score += 14;
  if (spanDays >= 60) score += 10;
  if (spanDays >= 90) score += 8;

  if (lifeAreaCount >= 2) score += 18;
  if (lifeAreaCount >= 3) score += 12;

  score += Math.min(20, signalBonus);
  score += Math.min(24, Math.max(-16, temporalBonus));

  let label: EvidenceStrengthLabel = "low";
  if (score >= 90) label = "very_high";
  else if (score >= 75) label = "high";
  else if (score >= 55) label = "medium";
  else label = "low";

  return { score, label };
}

export function impactScoreForInsight(
  insight: PatternInsight,
  entries: JournalEntry[],
  evidenceStrengthScore: number,
  extraBoost = 0,
): number {
  const entriesById = new Map(entries.map((e) => [e.id, e]));
  const blob = [
    insight.title,
    insight.detail,
    ...insight.evidence.map((e) => e.phrase),
    ...insight.entryIds
      .map((id) => entriesById.get(id))
      .filter(Boolean)
      .map((e) => e!.transcript),
  ].join(" ");

  const { score: signalScore, signalIds } = scoreImpactSignals(blob);
  const typeBase = TYPE_IMPACT_BASE[insight.type] ?? 10;
  const crossEntry = Math.min(24, insight.entryIds.length * 6);
  const recurrence = Math.min(20, insight.scores.recurrenceCount / 5);
  const evidenceBoost = Math.min(18, evidenceStrengthScore / 6);

  let impact = typeBase + signalScore + crossEntry + recurrence + evidenceBoost + extraBoost;

  if (insight.type === "avoidance_signal") impact += 12;
  if (insight.type === "contradiction") impact += 14;
  if (signalIds.includes("quitting_escape")) impact += 8;
  if (signalIds.includes("self_worth_collapse")) impact += 8;

  if (insight.type === "recurring_pattern" && extraBoost < 12) {
    impact -= 6;
  }

  return Math.round(impact);
}

export function passesBlindSpotEvidenceGate(input: {
  evidenceStrengthScore: number;
  evidenceStrengthLabel: EvidenceStrengthLabel;
  matchingReflections: number;
  minMatchingReflections?: number;
  evidenceQuoteCount: number;
  spanDays: number;
}): boolean {
  const minMatching = input.minMatchingReflections ?? MIN_MATCHING_REFLECTIONS;
  if (input.evidenceStrengthLabel === "low") return false;
  if (input.evidenceStrengthScore < MIN_SHOW_EVIDENCE_SCORE) return false;
  if (input.matchingReflections < minMatching) return false;
  if (input.evidenceQuoteCount < MIN_EVIDENCE_QUOTES) return false;
  if (input.spanDays < MIN_SPAN_DAYS && input.matchingReflections < 4) return false;
  return true;
}

export { buildEvidenceStrengthFacts };

export interface RankedBlindSpotCandidate {
  insight: PatternInsight;
  impactScore: number;
  evidenceStrengthScore: number;
  evidenceStrength: EvidenceStrengthLabel;
  matchingReflections: number;
  spanDays: number;
  lifeAreaCount: number;
  signalBonus: number;
  skepticPass: boolean;
  specificityScore: number;
  failedPredictionLinked: boolean;
  costEvidenceCount: number;
  contradictionPresent: boolean;
  temporalSpread: ReturnType<typeof analyzeEntryTemporalSpread>;
}

/** Rank blind-spot candidates with uncomfortably-accurate evidence weighting. */
export function rankBlindSpotCandidates(
  insights: PatternInsight[],
  entries: JournalEntry[],
  options?: {
    buildEvidenceQuotes?: (
      insight: PatternInsight,
      entriesById: Map<string, JournalEntry>,
    ) => { length: number };
  },
): RankedBlindSpotCandidate[] {
  const entriesById = new Map(entries.map((e) => [e.id, e]));
  const divergedIds = buildDivergedPredictionEntryIds(entries);
  const ranked: RankedBlindSpotCandidate[] = [];

  for (const insight of insights) {
    if (!BLIND_SPOT_TYPES.has(insight.type)) continue;
    if (insight.specificity.isWeakOrGeneric) continue;

    const matchingReflections = insight.entryIds.length;
    const minMatchingReflections =
      insight.type === "contradiction" ? 2 : MIN_MATCHING_REFLECTIONS;
    const quoteCount =
      options?.buildEvidenceQuotes?.(insight, entriesById)?.length ??
      Math.max(insight.evidence.length, insight.entryIds.length);
    const temporalSpread = analyzeEntryTemporalSpread(insight.entryIds, entriesById);
    const linkedAreas = linkedAreasForEntries(entries, insight.entryIds);
    const costEvidence = buildCostEvidence(insight.entryIds, entries);
    const costEvidenceCount = Object.values(costEvidence).reduce((s, n) => s + n, 0);
    const failedPredictionLinked = insightOverlapsFailedPrediction(insight, divergedIds);

    const signalBonus = signalBonusForInsight(insight);
    const temporalBonus = temporalSpreadScoreBonus(temporalSpread, matchingReflections);
    const { score: evidenceStrengthScore, label: evidenceStrength } = computeEvidenceStrength({
      matchingReflections,
      spanDays: temporalSpread.spanDays,
      lifeAreaCount: linkedAreas.length,
      signalBonus,
      temporalBonus,
    });

    const skepticCriteria = skepticCriteriaForInsight({
      insight,
      spanDays: temporalSpread.spanDays,
      lifeAreaCount: linkedAreas.length,
      costEvidenceCount,
      failedPredictionLinked,
    });

    if (
      !passesBlindSpotEvidenceGate({
        evidenceStrengthScore,
        evidenceStrengthLabel: evidenceStrength,
        matchingReflections,
        minMatchingReflections,
        evidenceQuoteCount: quoteCount,
        spanDays: temporalSpread.spanDays,
      })
    ) {
      continue;
    }

    if (!passesSkepticEvidenceGate(skepticCriteria)) {
      continue;
    }

    const accuracyBoosts = uncomfortableAccurateImpactBoost({
      insightType: insight.type,
      temporalSpread,
      matchingReflections,
      lifeAreaCount: linkedAreas.length,
      costEvidence,
      failedPredictionLinked,
    });
    const extraBoost = totalUncomfortableAccurateBoost(accuracyBoosts);

    const impactScore = impactScoreForInsight(insight, entries, evidenceStrengthScore, extraBoost);

    ranked.push({
      insight,
      impactScore,
      evidenceStrengthScore,
      evidenceStrength,
      matchingReflections,
      spanDays: temporalSpread.spanDays,
      lifeAreaCount: linkedAreas.length,
      signalBonus,
      skepticPass: true,
      specificityScore: computeSpecificityScore(skepticCriteria),
      failedPredictionLinked,
      costEvidenceCount,
      contradictionPresent: insight.type === "contradiction",
      temporalSpread,
    });
  }

  return ranked.sort((a, b) => {
    const headlineA = a.insight.title;
    const headlineB = b.insight.title;
    const scorecardA = buildInsightScorecardFromBlindSpotCandidate(a, headlineA).score;
    const scorecardB = buildInsightScorecardFromBlindSpotCandidate(b, headlineB).score;
    const profileA = buildInsightIngredientProfileFromCandidate(a, headlineA, scorecardA);
    const profileB = buildInsightIngredientProfileFromCandidate(b, headlineB, scorecardB);
    const scoreA = blindSpotPrioritizationScore(a, profileA, scorecardA);
    const scoreB = blindSpotPrioritizationScore(b, profileB, scorecardB);
    if (scoreB !== scoreA) return scoreB - scoreA;
    return b.evidenceStrengthScore - a.evidenceStrengthScore;
  });
}

function signalBonusForInsight(insight: PatternInsight): number {
  const blob = [insight.title, insight.detail, ...insight.evidence.map((e) => e.phrase)].join(
    " ",
  );
  let bonus = 0;
  if (insight.type === "contradiction") bonus += 14;
  if (insight.type === "avoidance_signal") bonus += 10;
  if (insight.type === "repeated_phrase") bonus += 6;
  if (/\bkeep\b|\bi always\b|\bmaybe\b/i.test(blob)) bonus += 4;
  return bonus;
}

export { MIN_SHOW_EVIDENCE_SCORE, MIN_MATCHING_REFLECTIONS, MIN_EVIDENCE_QUOTES, hasCostEvidence };
