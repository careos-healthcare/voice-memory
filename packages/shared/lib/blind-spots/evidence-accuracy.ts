import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { syncPredictionCandidates } from "@/lib/blind-spots/prediction-detection";
import { buildPredictionReview } from "@/lib/blind-spots/prediction-review";
import type { EvidenceStrengthFacts } from "@/types/blind-spot";

function formatEvidenceSpan(firstKey: string, lastKey: string): string {
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
import type { PatternInsight, PatternInsightType } from "@/lib/patterns/pattern-engine";
import type { CostEvidenceCounts } from "@/types/blind-spot-acceleration";
import type { JournalEntry } from "@/types/journal";

export const FORBIDDEN_ROOT_BELIEF =
  /\b(diagnos|disorder|narciss|toxic|therapy|trauma|clinical|patholog|you are a|you always are|guaranteed|certainly means you are)\b/i;

export interface EntryTemporalSpread {
  spanDays: number;
  distinctDayCount: number;
  distinctWeekCount: number;
  sameDayClusterRatio: number;
  firstDayKey: string;
  lastDayKey: string;
}

export interface SkepticEvidenceCriteria {
  hasContradiction: boolean;
  hasFailedPrediction: boolean;
  spanDays: number;
  lifeAreaCount: number;
  costEvidenceCount: number;
  isWeakOrGeneric: boolean;
}

export interface UncomfortableAccurateBoosts {
  temporalBonus: number;
  contradictionBonus: number;
  failedPredictionBonus: number;
  crossLifeAreaBonus: number;
  costEvidenceBonus: number;
}

export function analyzeEntryTemporalSpread(
  entryIds: string[],
  entriesById: Map<string, JournalEntry>,
): EntryTemporalSpread {
  const dayKeys = entryIds
    .map((id) => entriesById.get(id)?.createdAt)
    .filter(Boolean)
    .map((iso) => toDayKey(iso!));

  const today = toDayKey(new Date().toISOString());
  if (dayKeys.length === 0) {
    return {
      spanDays: 0,
      distinctDayCount: 0,
      distinctWeekCount: 0,
      sameDayClusterRatio: 1,
      firstDayKey: today,
      lastDayKey: today,
    };
  }

  const sorted = [...dayKeys].sort();
  const distinctDays = new Set(sorted);
  const weekKeys = new Set(sorted.map((k) => k.slice(0, 7)));
  const spanDays = Math.max(0, daysBetweenKeys(sorted[0]!, sorted[sorted.length - 1]!));
  const distinctDayCount = distinctDays.size;
  const distinctWeekCount = weekKeys.size;
  const sameDayClusterRatio =
    entryIds.length > 0 ? 1 - Math.min(1, distinctDayCount / entryIds.length) : 1;

  return {
    spanDays,
    distinctDayCount,
    distinctWeekCount,
    sameDayClusterRatio,
    firstDayKey: sorted[0]!,
    lastDayKey: sorted[sorted.length - 1]!,
  };
}

/** Rich span copy for evidence strength facts. */
export function formatRichSpanLabel(spread: EntryTemporalSpread): string {
  if (spread.spanDays >= 90) {
    const months = Math.max(3, Math.round(spread.spanDays / 30));
    return `Returned over ${months} months`;
  }
  if (spread.spanDays >= 60) {
    return "Returned over about 2 months";
  }
  if (spread.spanDays >= 30) {
    const days = Math.max(spread.spanDays, spread.distinctDayCount);
    return `Seen across ${days} days`;
  }
  if (spread.distinctDayCount >= 3) {
    return `Seen across ${spread.distinctDayCount} days`;
  }
  if (spread.spanDays >= 14) {
    return `Seen across ${spread.spanDays} days`;
  }
  if (spread.distinctDayCount >= 2) {
    return `Seen across ${spread.distinctDayCount} days`;
  }
  return spread.spanDays > 0 ? `${spread.spanDays} days` : "same day";
}

export function temporalSpreadScoreBonus(
  spread: EntryTemporalSpread,
  matchingReflections: number,
): number {
  let bonus = 0;
  if (spread.spanDays >= 30) bonus += 14;
  if (spread.spanDays >= 60) bonus += 10;
  if (spread.spanDays >= 90) bonus += 8;

  if (spread.distinctWeekCount >= 3) bonus += 6;
  if (spread.distinctDayCount >= 4) bonus += 4;

  if (spread.sameDayClusterRatio > 0.55 && spread.distinctWeekCount < 2 && matchingReflections >= 3) {
    bonus -= 14;
  } else if (spread.sameDayClusterRatio > 0.4 && spread.distinctWeekCount < 2) {
    bonus -= 8;
  }

  return bonus;
}

export function formatLifeAreaSpread(areas: string[]): string | null {
  if (areas.length < 2) return null;
  const labels = areas.slice(0, 3).map((a) => a.toLowerCase());
  if (labels.length === 2) {
    return `Appeared in ${labels[0]} and ${labels[1]}.`;
  }
  return `Appeared in ${labels.slice(0, -1).join(", ")}, and ${labels[labels.length - 1]}.`;
}

export function sumCostEvidenceCounts(counts: CostEvidenceCounts): number {
  return Object.values(counts).reduce((sum, n) => sum + n, 0);
}

export function costEvidenceRankBoost(counts: CostEvidenceCounts): number {
  const total = sumCostEvidenceCounts(counts);
  if (total === 0) return 0;
  return Math.min(28, 8 + total * 4);
}

export function contradictionRankBoost(insightType: PatternInsightType): number {
  if (insightType === "contradiction") return 32;
  return 0;
}

export function crossLifeAreaRankBoost(lifeAreaCount: number): number {
  if (lifeAreaCount >= 3) return 22;
  if (lifeAreaCount >= 2) return 16;
  return 0;
}

export function failedPredictionRankBoost(linked: boolean): number {
  return linked ? 26 : 0;
}

export function buildDivergedPredictionEntryIds(entries: JournalEntry[]): Set<string> {
  const candidates = syncPredictionCandidates(entries);
  const review = buildPredictionReview(candidates, entries);
  const ids = new Set<string>();
  for (const item of review.items) {
    if (item.outcomeStatus !== "diverged") continue;
    ids.add(item.candidate.entryId);
    if (item.laterEvidence) ids.add(item.laterEvidence.entryId);
  }
  return ids;
}

export function insightOverlapsFailedPrediction(
  insight: PatternInsight,
  divergedEntryIds: Set<string>,
): boolean {
  return insight.entryIds.some((id) => divergedEntryIds.has(id));
}

export function passesSkepticEvidenceGate(criteria: SkepticEvidenceCriteria): boolean {
  if (criteria.isWeakOrGeneric) return false;
  if (criteria.hasContradiction) return true;
  if (criteria.hasFailedPrediction) return true;
  if (criteria.spanDays >= 30) return true;
  if (criteria.lifeAreaCount >= 2) return true;
  if (criteria.costEvidenceCount > 0) return true;
  return false;
}

export function computeSpecificityScore(criteria: SkepticEvidenceCriteria): number {
  let score = 20;
  if (criteria.hasContradiction) score += 28;
  if (criteria.hasFailedPrediction) score += 24;
  if (criteria.spanDays >= 30) score += 18;
  if (criteria.spanDays >= 60) score += 8;
  if (criteria.lifeAreaCount >= 2) score += 16;
  if (criteria.costEvidenceCount > 0) score += Math.min(20, criteria.costEvidenceCount * 5);
  if (criteria.isWeakOrGeneric) score = Math.min(score, 22);
  return Math.min(100, score);
}

export function uncomfortableAccurateImpactBoost(input: {
  insightType: PatternInsightType;
  temporalSpread: EntryTemporalSpread;
  matchingReflections: number;
  lifeAreaCount: number;
  costEvidence: CostEvidenceCounts;
  failedPredictionLinked: boolean;
}): UncomfortableAccurateBoosts {
  return {
    temporalBonus: temporalSpreadScoreBonus(input.temporalSpread, input.matchingReflections),
    contradictionBonus: contradictionRankBoost(input.insightType),
    failedPredictionBonus: failedPredictionRankBoost(input.failedPredictionLinked),
    crossLifeAreaBonus: crossLifeAreaRankBoost(input.lifeAreaCount),
    costEvidenceBonus: costEvidenceRankBoost(input.costEvidence),
  };
}

export function totalUncomfortableAccurateBoost(boosts: UncomfortableAccurateBoosts): number {
  return (
    boosts.temporalBonus +
    boosts.contradictionBonus +
    boosts.failedPredictionBonus +
    boosts.crossLifeAreaBonus +
    boosts.costEvidenceBonus
  );
}

export function skepticCriteriaForInsight(input: {
  insight: PatternInsight;
  spanDays: number;
  lifeAreaCount: number;
  costEvidenceCount: number;
  failedPredictionLinked: boolean;
}): SkepticEvidenceCriteria {
  return {
    hasContradiction: input.insight.type === "contradiction",
    hasFailedPrediction: input.failedPredictionLinked,
    spanDays: input.spanDays,
    lifeAreaCount: input.lifeAreaCount,
    costEvidenceCount: input.costEvidenceCount,
    isWeakOrGeneric: input.insight.specificity.isWeakOrGeneric,
  };
}

export function sanitizeRootBelief(text: string): string {
  if (FORBIDDEN_ROOT_BELIEF.test(text)) {
    return "Your words may point to a repeating interpretation — still only a hypothesis.";
  }
  return text;
}

/** Hedged root-belief framing from strongest pattern signals — not a diagnosis. */
export function deriveRootBeliefHypothesis(
  insight: PatternInsight,
  signalIds: string[],
): string | null {
  const blob = [insight.title, insight.detail, ...insight.evidence.map((e) => e.phrase)].join(
    " ",
  );

  let hypothesis: string | null = null;

  if (insight.type === "contradiction") {
    hypothesis =
      "Conflict may be getting treated as proof something is broken — when two pulls might both be true.";
  } else if (signalIds.includes("self_worth_collapse") || /\bnot good enough\b|\bworthless\b/i.test(blob)) {
    hypothesis = "Criticism may be getting interpreted as rejection — not just feedback on one moment.";
  } else if (
    signalIds.includes("delayed_decision") ||
    /\bkeep waiting|eventually|monday\b/i.test(blob)
  ) {
    hypothesis = "Uncertainty may be getting treated as danger — waiting may feel safer than naming a next step.";
  } else if (signalIds.includes("quitting_escape") || /\bquit|give up|escape\b/i.test(blob)) {
    hypothesis = "Leaving may be appearing before you test whether the situation is actually closed.";
  } else if (signalIds.includes("avoidance") || insight.type === "avoidance_signal") {
    hypothesis = "Naming the real issue may be getting treated as riskier than circling it.";
  } else if (/\bconflict|fight|tension|at odds\b/i.test(blob)) {
    hypothesis = "Conflict may be getting treated as proof something is broken.";
  } else if (insight.type === "repeated_phrase" && /\balways|just|such a\b/i.test(blob)) {
    hypothesis = "A hard moment may be getting folded into a fixed story about who you always are.";
  } else if (insight.type === "recurring_pattern") {
    hypothesis = "The same concern returning may be getting treated as proof the answer never changed.";
  }

  if (!hypothesis) return null;
  return sanitizeRootBelief(hypothesis);
}

export const CONTRADICTION_ARCHIVE_COPY =
  "Two things in your archive may be pulling against each other.";

export const FAILED_PREDICTION_COPY =
  "You predicted this before; later evidence did not fully support it.";

export function buildEvidenceStrengthFacts(input: {
  matchingReflections: number;
  temporalSpread: EntryTemporalSpread;
  lifeAreas: string[];
  contradictionPresent: boolean;
  failedPredictionCount: number;
  costEvidenceCount: number;
  specificityScore: number;
  skepticPass: boolean;
}): EvidenceStrengthFacts {
  const richSpanLabel = formatRichSpanLabel(input.temporalSpread);
  const lifeAreaSpreadLabel = formatLifeAreaSpread(input.lifeAreas);

  return {
    reflectionCount: input.matchingReflections,
    spanLabel: formatEvidenceSpan(
      input.temporalSpread.firstDayKey,
      input.temporalSpread.lastDayKey,
    ),
    spanDays: input.temporalSpread.spanDays,
    richSpanLabel,
    lifeAreaCount: input.lifeAreas.length,
    lifeAreas: input.lifeAreas.length > 0 ? input.lifeAreas : ["General"],
    lifeAreaSpreadLabel: lifeAreaSpreadLabel ?? undefined,
    contradictionPresent: input.contradictionPresent,
    failedPredictionCount: input.failedPredictionCount,
    costEvidenceCount: input.costEvidenceCount,
    specificityScore: input.specificityScore,
    skepticPass: input.skepticPass,
  };
}
