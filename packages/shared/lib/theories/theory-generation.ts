import { buildBlindSpotAccelerationReport } from "@/lib/blind-spots/blind-spot-acceleration";
import { buildCostEvidence } from "@/lib/blind-spots/cost-evidence";
import {
  analyzeEntryTemporalSpread,
  buildDivergedPredictionEntryIds,
  computeSpecificityScore,
  deriveRootBeliefHypothesis,
  insightOverlapsFailedPrediction,
  passesSkepticEvidenceGate,
  skepticCriteriaForInsight,
  sumCostEvidenceCounts,
} from "@/lib/blind-spots/evidence-accuracy";
import {
  computeEvidenceStrength,
  linkedAreasForEntries,
  scoreImpactSignals,
} from "@/lib/blind-spots/blind-spot-ranking";
import {
  buildPatternEngineReport,
  type PatternInsight,
  type PatternInsightType,
} from "@/lib/patterns/pattern-engine";
import { buildWhatChanged } from "@/lib/theories/theory-changed";
import { resolveTheoryStatus } from "@/lib/theories/theory-resolution";
import {
  computeTheoryConfidence,
  lifeAreaCountForQuotes,
  spanDaysForQuotes,
} from "@/lib/theories/theory-confidence";
import {
  buildInsightScorecard,
  buildInsightScorecardFromTheory,
} from "@/lib/insights/insight-scorecard";
import { sanitizeTheoryCopy } from "@/lib/theories/theory-copy";
import { recordBeliefTimelineFromTheories } from "@/lib/archive/belief-timeline-storage";
import { readTheorySnapshot, upsertTheorySnapshots } from "@/lib/theories/theory-snapshots";
import { formatEntryDate } from "@/lib/utils";
import type {
  Theory,
  TheoryEvidenceQuote,
  TheorySource,
  TheoryTrackerReport,
} from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

const PATTERN_TYPES = new Set<PatternInsightType>([
  "contradiction",
  "avoidance_signal",
  "repeated_phrase",
  "recurring_pattern",
]);

interface TheoryDraft {
  id: string;
  statement: string;
  source: TheorySource;
  supportingEvidence: TheoryEvidenceQuote[];
  contradictingEvidence: TheoryEvidenceQuote[];
  supportingEvidenceCount: number;
  contradictingEvidenceCount: number;
  createdAt: string;
  evidenceStrengthScore?: number;
  isMixedContradiction?: boolean;
  rootBeliefHypothesis?: string;
  failedPredictionLinked?: boolean;
  costEvidenceCount?: number;
  specificityScore?: number;
}

function trimQuote(text: string): string {
  const n = text.replace(/\s+/g, " ").trim();
  return n.length <= 200 ? n : `${n.slice(0, 197)}…`;
}

function quotesFromInsight(
  insight: PatternInsight,
  entriesById: Map<string, JournalEntry>,
): TheoryEvidenceQuote[] {
  const fromInsight = insight.evidence
    .filter((e) => e.phrase?.trim())
    .map((e) => {
      const entry = entriesById.get(e.entryId);
      return {
        entryId: e.entryId,
        dateLabel: e.dateLabel ?? (entry ? formatEntryDate(entry.createdAt) : ""),
        quote: trimQuote(e.phrase),
      };
    });

  if (fromInsight.length >= 1) return fromInsight.slice(0, 4);

  return insight.entryIds.slice(0, 4).map((entryId) => {
    const entry = entriesById.get(entryId);
    return {
      entryId,
      dateLabel: entry ? formatEntryDate(entry.createdAt) : "",
      quote: trimQuote(entry?.transcript ?? ""),
    };
  });
}

function statementFromInsight(insight: PatternInsight): string {
  const detail = insight.detail.replace(/^You /i, "you ").trim();
  return sanitizeTheoryCopy(
    `Your recorded history may suggest: ${detail.charAt(0).toLowerCase()}${detail.slice(1)} This is a working theory — it may be wrong.`,
  );
}

function recognitionScoreForDraft(
  draft: TheoryDraft,
  entries: JournalEntry[],
  entriesById: Map<string, JournalEntry>,
): number {
  const spanDays = spanDaysForQuotes(draft.supportingEvidence, entriesById);
  const lifeAreas = lifeAreaCountForQuotes(draft.supportingEvidence, entries);
  return buildInsightScorecard({
    insightId: draft.id,
    surface:
      draft.source === "prediction"
        ? "prediction"
        : draft.source === "emerging"
          ? "emerging_pattern"
          : "theory",
    headline: draft.statement,
    sourceIds: draft.supportingEvidence.map((q) => q.entryId),
    ingredients: {
      contradiction: draft.contradictingEvidenceCount > 0,
      costEvidence: (draft.costEvidenceCount ?? 0) > 0,
      crossLifeArea: lifeAreas >= 2,
      longTimeSpanDays: spanDays,
      failedPrediction: Boolean(draft.failedPredictionLinked),
    },
  }).score;
}

function finalizeDraft(
  draft: TheoryDraft,
  entries: JournalEntry[],
  entriesById: Map<string, JournalEntry>,
): Theory {
  const snapshot = readTheorySnapshot(draft.id);
  const previousConfidence = snapshot?.confidence;
  const spanDays = spanDaysForQuotes(draft.supportingEvidence, entriesById);
  const lifeAreaCount = lifeAreaCountForQuotes(draft.supportingEvidence, entries);

  const confidence = computeTheoryConfidence({
    supportingCount: draft.supportingEvidenceCount,
    contradictingCount: draft.contradictingEvidenceCount,
    spanDays,
    lifeAreaCount,
    evidenceStrengthScore: draft.evidenceStrengthScore,
    isMixedContradiction: draft.isMixedContradiction,
    failedPredictionLinked: draft.failedPredictionLinked,
    costEvidenceCount: draft.costEvidenceCount,
    specificityScore: draft.specificityScore,
  });

  const confidenceDelta =
    previousConfidence !== undefined ? confidence - previousConfidence : 0;

  const isFirstSnapshot = previousConfidence === undefined;
  const { status, resolutionNote } = resolveTheoryStatus({
    confidence,
    confidenceDelta,
    isFirstSnapshot,
    createdAt: draft.createdAt,
    supportingCount: draft.supportingEvidenceCount,
    contradictingCount: draft.contradictingEvidenceCount,
    baselineContradictingCount: snapshot?.contradictingCount,
    contradictingQuotes: draft.contradictingEvidence,
    entriesById,
  });

  const newSupportingSinceLast =
    previousConfidence !== undefined && confidenceDelta > 0
      ? Math.max(1, Math.round(confidenceDelta / 4))
      : undefined;

  const whatChanged = buildWhatChanged({
    status,
    confidenceDelta,
    supportingEvidenceCount: draft.supportingEvidenceCount,
    contradictingEvidenceCount: draft.contradictingEvidenceCount,
    newSupportingSinceLast,
    isFirstSnapshot,
    resolutionNote,
  });

  const now = new Date().toISOString();

  const theory: Theory = {
    id: draft.id,
    statement: draft.statement,
    confidence,
    previousConfidence,
    confidenceDelta,
    supportingEvidenceCount: draft.supportingEvidenceCount,
    contradictingEvidenceCount: draft.contradictingEvidenceCount,
    createdAt: draft.createdAt,
    updatedAt: now,
    status,
    resolutionNote,
    supportingEvidence: draft.supportingEvidence,
    contradictingEvidence: draft.contradictingEvidence,
    whatChanged,
    source: draft.source,
    rootBeliefHypothesis: draft.rootBeliefHypothesis,
  };

  theory.scorecard = buildInsightScorecardFromTheory(theory, entriesById);
  return theory;
}

function draftFromBlindSpot(
  review: import("@/types/blind-spot").BlindSpotReviewResult,
): TheoryDraft {
  const supporting = review.evidenceQuotes.map((q) => ({
    entryId: q.entryId,
    dateLabel: q.dateLabel,
    quote: q.quote,
  }));
  return {
    id: `theory:blind_spot:${review.reviewId}`,
    statement: sanitizeTheoryCopy(review.possibleBelief),
    source: "blind_spot",
    supportingEvidence: supporting,
    contradictingEvidence: [],
    supportingEvidenceCount: supporting.length,
    contradictingEvidenceCount: 0,
    createdAt: review.generatedAt,
    evidenceStrengthScore:
      review.evidenceStrength === "very_high"
        ? 90
        : review.evidenceStrength === "high"
          ? 78
          : review.evidenceStrength === "medium"
            ? 62
            : 45,
    rootBeliefHypothesis: review.rootBeliefHypothesis,
    failedPredictionLinked: Boolean(review.predictionEvidenceNote),
    costEvidenceCount: review.evidenceStrengthFacts.costEvidenceCount,
    specificityScore: review.specificityScore,
  };
}

function draftFromEmerging(
  pattern: import("@/types/blind-spot-acceleration").EmergingPattern,
): TheoryDraft {
  const supporting = pattern.evidenceQuotes;
  return {
    id: `theory:emerging:${pattern.id}`,
    statement: sanitizeTheoryCopy(pattern.hypothesis),
    source: "emerging",
    supportingEvidence: supporting,
    contradictingEvidence: [],
    supportingEvidenceCount: pattern.matchingReflections,
    contradictingEvidenceCount: 0,
    createdAt: new Date().toISOString(),
    evidenceStrengthScore: 48,
  };
}

function draftFromPrediction(
  item: import("@/types/blind-spot-acceleration").PredictionReviewItem,
): TheoryDraft | null {
  if (!item.laterEvidence) return null;
  const supporting: TheoryEvidenceQuote[] = [
    {
      entryId: item.candidate.entryId,
      dateLabel: item.candidate.dateLabel,
      quote: trimQuote(item.candidate.quote),
    },
    {
      entryId: item.laterEvidence.entryId,
      dateLabel: item.laterEvidence.dateLabel,
      quote: item.laterEvidence.quote,
    },
  ];
  const contradicting =
    item.outcomeStatus === "diverged"
      ? [item.laterEvidence]
      : item.outcomeStatus === "aligned"
        ? []
        : [];

  return {
    id: `theory:prediction:${item.candidate.id}`,
    statement: sanitizeTheoryCopy(
      `You may have expected one outcome; your later reflection suggests: ${item.outcomeSummary}`,
    ),
    source: "prediction",
    supportingEvidence: supporting,
    contradictingEvidence: contradicting,
    supportingEvidenceCount: supporting.length,
    contradictingEvidenceCount: contradicting.length,
    createdAt: item.candidate.predictedAt,
    evidenceStrengthScore: item.outcomeStatus === "pending" ? 40 : 58,
    isMixedContradiction: item.outcomeStatus === "unclear",
    failedPredictionLinked: item.outcomeStatus === "diverged",
    specificityScore: item.outcomeStatus === "diverged" ? 62 : 40,
  };
}

function draftFromInsight(
  insight: PatternInsight,
  entries: JournalEntry[],
  entriesById: Map<string, JournalEntry>,
  divergedIds: Set<string>,
): TheoryDraft | null {
  if (!PATTERN_TYPES.has(insight.type)) return null;
  if (insight.entryIds.length < 2) return null;
  if (insight.specificity.isWeakOrGeneric) return null;

  const supporting = quotesFromInsight(insight, entriesById);
  if (supporting.length < 2) return null;

  const temporalSpread = analyzeEntryTemporalSpread(insight.entryIds, entriesById);
  const linkedAreas = linkedAreasForEntries(entries, insight.entryIds);
  const costEvidence = buildCostEvidence(insight.entryIds, entries);
  const costEvidenceCount = sumCostEvidenceCounts(costEvidence);
  const failedPredictionLinked = insightOverlapsFailedPrediction(insight, divergedIds);
  const skeptic = skepticCriteriaForInsight({
    insight,
    spanDays: temporalSpread.spanDays,
    lifeAreaCount: linkedAreas.length,
    costEvidenceCount,
    failedPredictionLinked,
  });
  if (!passesSkepticEvidenceGate(skeptic)) return null;

  const strength = computeEvidenceStrength({
    matchingReflections: insight.entryIds.length,
    spanDays: temporalSpread.spanDays,
    lifeAreaCount: linkedAreas.length,
    signalBonus: insight.type === "contradiction" ? 12 : 0,
    temporalBonus: temporalSpread.spanDays >= 30 ? 10 : 0,
  });

  let contradicting: TheoryEvidenceQuote[] = [];
  if (insight.type === "contradiction" && insight.evidence.length >= 2) {
    contradicting = insight.evidence.slice(1, 3).map((e) => ({
      entryId: e.entryId,
      dateLabel: e.dateLabel ?? "",
      quote: trimQuote(e.phrase),
    }));
  }

  const blob = [insight.title, insight.detail, ...insight.evidence.map((e) => e.phrase)].join(" ");
  const { signalIds } = scoreImpactSignals(blob);

  return {
    id: `theory:pattern:${insight.type}:${insight.sourceKey}`,
    statement: statementFromInsight(insight),
    source: "pattern",
    supportingEvidence: supporting,
    contradictingEvidence: contradicting,
    supportingEvidenceCount: insight.entryIds.length,
    contradictingEvidenceCount: contradicting.length,
    createdAt: new Date().toISOString(),
    evidenceStrengthScore: strength.score,
    isMixedContradiction: insight.type === "contradiction" && contradicting.length > 0,
    rootBeliefHypothesis: deriveRootBeliefHypothesis(insight, signalIds) ?? undefined,
    failedPredictionLinked,
    costEvidenceCount,
    specificityScore: computeSpecificityScore(skeptic),
  };
}

/** Build living theories from existing blind spot / pattern / prediction infrastructure. */
export function buildTheoryTrackerReport(
  entries: JournalEntry[],
  options?: { persistSnapshots?: boolean },
): TheoryTrackerReport {
  const persistSnapshots = options?.persistSnapshots !== false;
  const eligible = entries.filter((e) => e.reflectionPending !== true);
  const entriesById = new Map(eligible.map((e) => [e.id, e]));
  const divergedIds = buildDivergedPredictionEntryIds(eligible);
  const drafts: TheoryDraft[] = [];
  const seenIds = new Set<string>();

  const push = (draft: TheoryDraft | null) => {
    if (!draft || seenIds.has(draft.id)) return;
    seenIds.add(draft.id);
    drafts.push(draft);
  };

  const acceleration = buildBlindSpotAccelerationReport(entries);

  if (acceleration.mainReview.kind === "ready") {
    push(draftFromBlindSpot(acceleration.mainReview.review));
  }

  for (const pattern of acceleration.emergingPatterns) {
    push(draftFromEmerging(pattern));
  }

  for (const item of acceleration.predictionReview.items) {
    push(draftFromPrediction(item));
  }

  if (eligible.length >= 2) {
    const engine = buildPatternEngineReport(eligible, { scope: "archive", limit: 16 });
    for (const insight of engine.insights) {
      if (drafts.length >= 12) break;
      const blindSpotId = `theory:blind_spot:blind-spot:${insight.type}:${insight.sourceKey}`;
      const emergingId = `theory:emerging:emerging:${insight.type}:${insight.sourceKey}`;
      if (seenIds.has(blindSpotId) || seenIds.has(emergingId)) continue;
      push(draftFromInsight(insight, eligible, entriesById, divergedIds));
    }
  }

  drafts.sort((a, b) => recognitionScoreForDraft(b, eligible, entriesById) - recognitionScoreForDraft(a, eligible, entriesById));

  const theories = drafts.map((d) => finalizeDraft(d, eligible, entriesById));

  if (persistSnapshots) {
    upsertTheorySnapshots(
      theories.map((t) => ({
        theoryId: t.id,
        confidence: t.confidence,
        contradictingCount: t.contradictingEvidenceCount,
      })),
    );
    recordBeliefTimelineFromTheories(theories, eligible);
  }

  const active = theories.filter((t) => t.status === "active");
  const strengthening = theories.filter((t) => t.status === "strengthening");
  const weakening = theories.filter((t) => t.status === "weakening");
  const resolved = theories.filter((t) => t.status === "resolved");
  const retired = theories.filter((t) => t.status === "retired");

  return {
    generatedAt: new Date().toISOString(),
    active,
    strengthening,
    weakening,
    resolved,
    retired,
    all: theories,
  };
}

/** Seed-friendly: ensure at least one theory from fixture-like entries. */
export function buildTheoriesForEval(entries: JournalEntry[]): Theory[] {
  return buildTheoryTrackerReport(entries).all;
}
