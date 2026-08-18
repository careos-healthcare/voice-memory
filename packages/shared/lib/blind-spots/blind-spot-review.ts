import {
  buildPatternEngineReport,
  type PatternInsight,
} from "@/lib/patterns/pattern-engine";
import { formatEntryDate } from "@/lib/utils";
import {
  BLIND_SPOT_EMPTY_MESSAGE,
  BLIND_SPOT_MIN_REFLECTIONS,
  BLIND_SPOT_WEAK_EVIDENCE_MESSAGE,
} from "@/lib/blind-spots/blind-spot-copy";
import {
  buildCostEvidence,
  formatCostEvidenceLine,
} from "@/lib/blind-spots/cost-evidence";
import {
  CONTRADICTION_ARCHIVE_COPY,
  deriveRootBeliefHypothesis,
  FAILED_PREDICTION_COPY,
} from "@/lib/blind-spots/evidence-accuracy";
import { buildBlindSpotExperiment } from "@/lib/blind-spots/blind-spot-experiment";
import { buildBlindSpotReviewChanges } from "@/lib/blind-spots/blind-spot-review-delta";
import { buildATierWhyMatterBullets } from "@/lib/blind-spots/a-tier-prioritization";
import { attachBlindSpotConfidenceFields } from "@/lib/blind-spots/blind-spot-confidence";
import { readLatestBlindSpotReviewSnapshot } from "@/lib/blind-spots/blind-spot-review-snapshots";
import { blindSpotPrioritizationScore } from "@/lib/blind-spots/a-tier-prioritization";
import { buildInsightIngredientProfileFromCandidate } from "@/lib/insights/insight-ingredient-optimizer";
import {
  buildInsightScorecardFromBlindSpotCandidate,
  scorecardTieBreakBoost,
} from "@/lib/insights/insight-scorecard";
import {
  buildEvidenceStrengthFacts,
  linkedAreasForEntries,
  rankBlindSpotCandidates,
  scoreImpactSignals,
  type RankedBlindSpotCandidate,
} from "@/lib/blind-spots/blind-spot-ranking";
import { hasCostEvidence, possibleCostLead } from "@/lib/blind-spots/cost-evidence";
import type { JournalEntry } from "@/types/journal";
import type {
  BlindSpotEvidenceQuote,
  BlindSpotReviewReport,
  BlindSpotReviewResult,
} from "@/types/blind-spot";

const FORBIDDEN_OUTPUT =
  /\b(diagnos|disorder|narciss|toxic|therapy|trauma|clinical|patholog|guaranteed|will always cause|certainly means you are)\b/i;

type RankedCandidate = RankedBlindSpotCandidate;

function extractPhraseAnchor(insight: PatternInsight): string {
  const match = insight.title.match(/"([^"]+)"/);
  if (match?.[1]) return match[1];
  const evidencePhrase = insight.evidence[0]?.phrase?.trim();
  if (evidencePhrase && evidencePhrase.length <= 48) return evidencePhrase;
  return "this wording";
}

function headlineFor(insight: PatternInsight): string {
  switch (insight.type) {
    case "contradiction":
      return CONTRADICTION_ARCHIVE_COPY;
    case "avoidance_signal":
      return "One possible pattern: circling without naming";
    case "repeated_phrase":
      return `One possible pattern: returning to “${extractPhraseAnchor(insight)}”`;
    case "recurring_pattern":
      return "One possible pattern: the same concern keeps returning";
    default:
      return "One possible pattern in how you talk to yourself";
  }
}

function possibleBeliefFor(insight: PatternInsight, linkedAreas: string[]): string {
  const areaHint =
    linkedAreas.length > 0
      ? ` across ${linkedAreas.slice(0, 3).join(", ").toLowerCase()}`
      : "";
  switch (insight.type) {
    case "contradiction":
      return `Your words suggest you may be carrying two competing stories at once${areaHint} — wanting one thing while acting as if another is true.`;
    case "avoidance_signal":
      return `Your words suggest you may believe naming the real issue is riskier than circling it${areaHint}.`;
    case "repeated_phrase":
      return `Your words suggest you may believe “${extractPhraseAnchor(insight)}” is the honest summary of what is happening${areaHint}.`;
    case "recurring_pattern":
      return `Your words suggest you may believe this concern still needs the same answer${areaHint} — even when the situation shifts.`;
    default:
      return `Your words suggest a repeating belief may be running in the background${areaHint}.`;
  }
}

function patternDescriptionFor(insight: PatternInsight): string {
  const detail = insight.detail.replace(/^You /i, "you ").trim();
  return `This may be a repeating thread in your thinking history. Your words suggest ${detail.charAt(0).toLowerCase()}${detail.slice(1)}`;
}

function observationFor(
  insight: PatternInsight,
  evidenceQuotes: BlindSpotEvidenceQuote[],
  matchingReflections: number,
): string {
  const lead =
    evidenceQuotes[0]?.quote ??
    insight.evidence[0]?.phrase ??
    insight.detail.slice(0, 120);
  const trimmed = lead.replace(/\s+/g, " ").trim();
  return `Your words suggest this thread appeared across ${matchingReflections} reflections — e.g. “${trimmed.slice(0, 120)}${trimmed.length > 120 ? "…" : ""}”. This is observation only, not a conclusion.`;
}

function likelyCostFor(insight: PatternInsight, signalIds: string[]): string {
  if (signalIds.includes("quitting_escape")) {
    return "This may cost you follow-through — escape language can arrive before you test whether the situation is actually closed.";
  }
  if (signalIds.includes("self_worth_collapse")) {
    return "This may cost you proportion — a hard moment can get folded into a fixed story about who you always are.";
  }
  if (signalIds.includes("delayed_decision")) {
    return "This may cost you momentum — delayed decisions can stack until the next step feels heavier than the original choice.";
  }
  switch (insight.type) {
    case "contradiction":
      return "This may cost you momentum — holding two opposite stories can make the next step feel impossible before you start.";
    case "avoidance_signal":
      return "This may cost you clarity — staying indirect can keep the real question off the table even when you are trying to be honest.";
    case "repeated_phrase":
      if (/soften|maybe|guess|don't know/i.test(insight.title)) {
        return "This may cost you directness — softening every line can read as uncertainty even when you already know what you feel.";
      }
      if (/always|just|such a/i.test(insight.title)) {
        return "This may cost you flexibility — a fixed label can turn one hard day into a story about who you always are.";
      }
      return "This may cost you perspective — the same phrase can shrink a complex week into a single repeated story.";
    case "recurring_pattern":
      return "This may cost you closure — returning to the same concern without a new conclusion can keep the loop open.";
    default:
      return "This may cost you energy — repeating the same frame without testing it can keep you circling.";
  }
}

function ifThisDisappearedFor(insight: PatternInsight, signalIds: string[]): string {
  if (signalIds.includes("avoidance") || insight.type === "avoidance_signal") {
    return "If this pattern softened, some avoidance loops and quitting thoughts may become easier to test before acting.";
  }
  if (signalIds.includes("quitting_escape")) {
    return "If this pattern softened, leaving or quitting might show up as a choice you make once — not a reflex that arrives first.";
  }
  if (signalIds.includes("self_worth_collapse")) {
    return "If this pattern softened, a hard day might stay local — instead of becoming proof about your whole character.";
  }
  if (signalIds.includes("delayed_decision") || signalIds.includes("wrong_prediction")) {
    return "If this pattern softened, you might name one next step without waiting for the perfect Monday or the perfect mood.";
  }
  if (insight.type === "contradiction") {
    return "If this pattern softened, want and habit might sit side by side — without forcing you to pick a verdict about yourself first.";
  }
  return "If this pattern softened, the same situation might leave room for a new sentence instead of the same closing line.";
}

function alternativeFor(insight: PatternInsight): string {
  switch (insight.type) {
    case "contradiction":
      return "One alternative to test next time: both statements might be true at once — want and habit pulling in different directions, not failure.";
    case "avoidance_signal":
      return "One alternative to test next time: indirect wording might be care — protecting something tender before you name it out loud.";
    case "repeated_phrase":
      if (/soften|maybe|guess/i.test(insight.title)) {
        return "One alternative to test next time: hedging might be pacing — giving yourself room before you commit to a hard sentence.";
      }
      if (/always|just|such a/i.test(insight.title)) {
        return "One alternative to test next time: the label might describe one moment, not your whole character.";
      }
      return "One alternative to test next time: the phrase might be a shorthand for something specific — name the situation once and see if the habit loosens.";
    case "recurring_pattern":
      return "One alternative to test next time: the theme might be unfinished care — something you keep checking because it still matters, not because you are stuck.";
    default:
      return "One alternative to test next time: the repetition might be signal — your mind flagging what still needs one honest sentence.";
  }
}

function buildEvidenceQuotes(
  insight: PatternInsight,
  entriesById: Map<string, JournalEntry>,
): BlindSpotEvidenceQuote[] {
  const fromInsight = insight.evidence
    .filter((e) => e.phrase?.trim())
    .slice(0, 5)
    .map((e) => {
      const entry = entriesById.get(e.entryId);
      return {
        entryId: e.entryId,
        dateLabel: e.dateLabel ?? (entry ? formatEntryDate(entry.createdAt) : ""),
        quote: trimQuote(e.phrase),
      };
    });

  if (fromInsight.length >= 2) return fromInsight;

  const fallback: BlindSpotEvidenceQuote[] = [];
  for (const entryId of insight.entryIds.slice(0, 5)) {
    const entry = entriesById.get(entryId);
    if (!entry) continue;
    const quote =
      entry.reflection.exactLanguagePattern?.trim() ||
      entry.reflection.repeatedSignal?.trim() ||
      entry.reflection.concreteObservation?.trim() ||
      entry.transcript.trim().slice(0, 160);
    if (!quote) continue;
    fallback.push({
      entryId,
      dateLabel: formatEntryDate(entry.createdAt),
      quote: trimQuote(quote),
    });
  }

  return fallback.length > 0 ? fallback : fromInsight;
}

function trimQuote(text: string): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (normalized.length <= 220) return normalized;
  return `${normalized.slice(0, 217)}…`;
}

function sanitizeCopy(text: string): string {
  if (FORBIDDEN_OUTPUT.test(text)) {
    return "This may be a repeating thread worth revisiting in your own words — not a label about you.";
  }
  return text;
}

function buildReviewFromCandidate(
  candidate: RankedCandidate,
  entries: JournalEntry[],
): BlindSpotReviewResult {
  const { insight } = candidate;
  const entriesById = new Map(entries.map((e) => [e.id, e]));
  const evidenceQuotes = buildEvidenceQuotes(insight, entriesById);
  const linkedAreas = linkedAreasForEntries(entries, insight.entryIds);
  const blob = [insight.title, insight.detail, ...evidenceQuotes.map((q) => q.quote)].join(" ");
  const { signalIds } = scoreImpactSignals(blob);

  const likelyCost = sanitizeCopy(likelyCostFor(insight, signalIds));
  const ifThisDisappeared = sanitizeCopy(ifThisDisappearedFor(insight, signalIds));
  const costEvidence = buildCostEvidence(insight.entryIds, entries);
  const costEvidenceLines = formatCostEvidenceLine(costEvidence);
  const costLead = possibleCostLead(costEvidence);
  const rootBeliefHypothesis = deriveRootBeliefHypothesis(insight, signalIds) ?? undefined;
  const contradictionNote =
    candidate.contradictionPresent || insight.type === "contradiction"
      ? CONTRADICTION_ARCHIVE_COPY
      : undefined;
  const predictionEvidenceNote = candidate.failedPredictionLinked
    ? FAILED_PREDICTION_COPY
    : undefined;

  const evidenceStrengthFacts = buildEvidenceStrengthFacts({
    matchingReflections: candidate.matchingReflections,
    temporalSpread: candidate.temporalSpread,
    lifeAreas: linkedAreas,
    contradictionPresent: candidate.contradictionPresent,
    failedPredictionCount: candidate.failedPredictionLinked ? 1 : 0,
    costEvidenceCount: candidate.costEvidenceCount,
    specificityScore: candidate.specificityScore,
    skepticPass: candidate.skepticPass,
  });

  const headline = sanitizeCopy(headlineFor(insight));
  const scorecard = buildInsightScorecardFromBlindSpotCandidate(candidate, headline);
  const ingredientProfile = buildInsightIngredientProfileFromCandidate(
    candidate,
    headline,
    scorecard.score,
  );
  const experiment = buildBlindSpotExperiment({
    insight,
    signalIds,
    evidenceStrengthFacts,
    failedPredictionLinked: candidate.failedPredictionLinked,
    evidenceStrength: candidate.evidenceStrength,
    scorecardScore: scorecard.score,
  });

  const baseReview = {
    reviewId: `blind-spot:${insight.type}:${insight.sourceKey}`,
    headline,
    scorecard,
    ingredientProfile,
    experiment: experiment ?? undefined,
    observation: sanitizeCopy(
      observationFor(insight, evidenceQuotes, candidate.matchingReflections),
    ),
    possibleBelief: sanitizeCopy(possibleBeliefFor(insight, linkedAreas)),
    pattern: sanitizeCopy(patternDescriptionFor(insight)),
    costEvidence,
    costEvidenceLines,
    likelyCost,
    evidenceQuotes,
    evidenceStrength: candidate.evidenceStrength,
    evidenceStrengthFacts,
    linkedAreas: linkedAreas.length > 0 ? linkedAreas : ["General"],
    rootBeliefHypothesis,
    contradictionNote,
    predictionEvidenceNote,
    possibleCostLead: costLead ?? undefined,
    specificityScore: candidate.specificityScore,
    alternativeToTest: sanitizeCopy(alternativeFor(insight)),
    ifThisDisappeared,
    whyThisMatters: sanitizeCopy(`${likelyCost} ${ifThisDisappeared}`),
    disclaimer:
      "Built from your saved reflections only. This may be incomplete or off — use it as a hypothesis, not a verdict.",
    reflectionCount: entries.length,
    archiveEntryIds: entries.map((e) => e.id).sort(),
    estimatedImpactScore: candidate.impactScore,
    generatedAt: new Date().toISOString(),
  };
  const withConfidence = attachBlindSpotConfidenceFields(baseReview);
  return {
    ...withConfidence,
    whyMatterBullets: buildATierWhyMatterBullets(
      withConfidence,
      ingredientProfile,
      entries,
    ),
  };
}

/** Analyze reflections for the highest-impact evidence-backed blind spot. */
export function buildBlindSpotReview(entries: JournalEntry[]): BlindSpotReviewReport {
  const eligible = entries.filter((e) => e.reflectionPending !== true);
  const count = eligible.length;

  if (count < BLIND_SPOT_MIN_REFLECTIONS) {
    return {
      kind: "empty",
      reason: "insufficient_reflections",
      reflectionCount: count,
      message: BLIND_SPOT_EMPTY_MESSAGE,
    };
  }

  const report = buildPatternEngineReport(eligible, {
    scope: "archive",
    limit: 40,
  });

  const ranked = rankBlindSpotCandidates(report.insights, eligible, {
    buildEvidenceQuotes: (insight, map) => ({
      length: buildEvidenceQuotes(insight, map).length,
    }),
  });
  const priorSnapshot = readLatestBlindSpotReviewSnapshot();
  const archiveEntryIds = eligible.map((e) => e.id).sort();
  const winner = pickWinnerAvoidingStaleRepeat(
    ranked,
    priorSnapshot,
    count,
    archiveEntryIds,
  );

  if (!winner || winner.evidenceStrength === "low" || !winner.skepticPass) {
    return {
      kind: "empty",
      reason: "weak_evidence",
      reflectionCount: count,
      message: BLIND_SPOT_WEAK_EVIDENCE_MESSAGE,
    };
  }

  const review = buildReviewFromCandidate(winner, eligible);
  if (review.evidenceQuotes.length < 2) {
    return {
      kind: "empty",
      reason: "weak_evidence",
      reflectionCount: count,
      message: BLIND_SPOT_WEAK_EVIDENCE_MESSAGE,
    };
  }

  const sinceLastTime = buildBlindSpotReviewChanges(review, priorSnapshot);

  return { kind: "ready", review, sinceLastTime };
}

function pickWinnerAvoidingStaleRepeat(
  ranked: RankedCandidate[],
  prior: ReturnType<typeof readLatestBlindSpotReviewSnapshot>,
  archiveReflectionCount: number,
  archiveEntryIds: string[],
): RankedCandidate | undefined {
  if (ranked.length === 0) return undefined;

  const archiveUnchanged =
    prior && archiveContentsUnchanged(prior, archiveEntryIds, archiveReflectionCount);
  if (archiveUnchanged) {
    const sticky = ranked.find(
      (c) => reviewIdForCandidate(c) === prior.reviewId,
    );
    if (sticky && sticky.evidenceStrength !== "low" && sticky.skepticPass) {
      return sticky;
    }
  }

  const scored = ranked.map((candidate) => ({
    candidate,
    composite: compositeWinnerScore(candidate, prior, archiveEntryIds),
  }));

  scored.sort((a, b) => b.composite - a.composite);
  return scored[0]?.candidate;
}

function reviewIdForCandidate(candidate: RankedCandidate): string {
  return `blind-spot:${candidate.insight.type}:${candidate.insight.sourceKey}`;
}

function archiveContentsUnchanged(
  prior: NonNullable<ReturnType<typeof readLatestBlindSpotReviewSnapshot>>,
  archiveEntryIds: string[],
  archiveReflectionCount: number,
): boolean {
  const priorArchive = prior.archiveEntryIds ?? [];
  if (priorArchive.length > 0) {
    if (priorArchive.length !== archiveEntryIds.length) return false;
    const priorSet = new Set(priorArchive);
    return archiveEntryIds.every((id) => priorSet.has(id));
  }
  return archiveReflectionCount <= (prior.archiveReflectionCount || 0);
}

function compositeWinnerScore(
  candidate: RankedCandidate,
  prior: ReturnType<typeof readLatestBlindSpotReviewSnapshot>,
  archiveEntryIds: string[],
): number {
  const headline = headlineFor(candidate.insight);
  const scorecardScore = buildInsightScorecardFromBlindSpotCandidate(
    candidate,
    headline,
  ).score;

  const ingredientProfile = buildInsightIngredientProfileFromCandidate(
    candidate,
    headline,
    scorecardScore,
  );

  let total =
    blindSpotPrioritizationScore(candidate, ingredientProfile, scorecardScore) +
    scorecardTieBreakBoost(scorecardScore) +
    Math.round(scorecardScore * 0.15);

  if (!prior) return total;

  const reviewId = reviewIdForCandidate(candidate);
  const newEntryIds = candidate.insight.entryIds.filter((id) => !prior.entryIds.includes(id));
  const priorAppliesToArchive = archiveContentsUnchanged(
    prior,
    archiveEntryIds,
    archiveEntryIds.length,
  );

  if (priorAppliesToArchive) {
    if (prior.reviewId === reviewId && newEntryIds.length === 0) {
      total -= 50;
    } else if (prior.reviewId === reviewId) {
      total += newEntryIds.length * 5;
    }

    if (prior.headline === headline && newEntryIds.length === 0) {
      total -= 30;
    }
  } else {
    if (prior.reviewId === reviewId) {
      total -= 45;
    }
    if (
      prior.patternType === "recurring_pattern" &&
      candidate.insight.type === "contradiction"
    ) {
      total += 90;
    }
    if (scorecardScore > prior.scorecardScore + 3) {
      total += Math.round((scorecardScore - prior.scorecardScore) * 3);
    }
  }

  return total;
}
