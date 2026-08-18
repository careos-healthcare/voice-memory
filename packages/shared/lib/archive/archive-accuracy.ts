import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { readArchiveFollowupAnswers } from "@/lib/archive/archive-followup-storage";
import { buildBlindSpotAccelerationReport } from "@/lib/blind-spots/blind-spot-acceleration";
import { readAllExperimentCommitments } from "@/lib/blind-spots/blind-spot-experiment-commitment";
import { assertNoCertaintyLanguage } from "@/lib/theories/theory-confidence-movement";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { theoryToPersonalTheory } from "@/lib/theories/personal-theory-map";
import { readAllInsightOutcomeEvents } from "@/lib/insights/insight-outcome-storage";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveAccuracyView,
  ArchiveBeliefAccuracyRow,
  ArchiveBeliefAccuracyStatus,
} from "@/types/archive-accuracy";
import type { PredictionReviewItem } from "@/types/blind-spot-acceleration";
import type { InsightOutcomeResponse } from "@/types/insight-outcome";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

export const ARCHIVE_ACCURACY_TITLE = "Archive accuracy";

export const ARCHIVE_ACCURACY_STATUS_LABEL: Record<ArchiveBeliefAccuracyStatus, string> = {
  confirmed: "Confirmed",
  challenged: "Challenged",
  unclear: "Unclear",
};

const CONFIRMED_OUTCOMES = new Set<InsightOutcomeResponse>([
  "caught_it_earlier",
  "acted_differently",
  "problem_improved",
  "noticed_pattern",
]);

const MAX_BELIEFS = 8;

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function mergeStatuses(statuses: ArchiveBeliefAccuracyStatus[]): ArchiveBeliefAccuracyStatus {
  if (statuses.includes("challenged")) return "challenged";
  if (statuses.includes("confirmed")) return "confirmed";
  return "unclear";
}

function statusFromPrediction(item: PredictionReviewItem | undefined): {
  status: ArchiveBeliefAccuracyStatus;
  detail: string | null;
} | null {
  if (!item) return null;
  if (!item.laterEvidence && item.outcomeStatus === "pending") {
    return { status: "unclear", detail: item.outcomeSummary };
  }
  if (item.outcomeStatus === "aligned") {
    return { status: "confirmed", detail: item.outcomeSummary };
  }
  if (item.outcomeStatus === "diverged") {
    return { status: "challenged", detail: item.outcomeSummary };
  }
  return { status: "unclear", detail: item.outcomeSummary };
}

function statusFromInsightOutcome(
  outcome: InsightOutcomeResponse | undefined,
): ArchiveBeliefAccuracyStatus | null {
  if (!outcome) return null;
  if (CONFIRMED_OUTCOMES.has(outcome)) return "confirmed";
  if (outcome === "theory_stopped_fitting") return "challenged";
  return "unclear";
}

function statusFromTheorySignals(theory: Theory): ArchiveBeliefAccuracyStatus {
  if (theory.status === "weakening" || theory.contradictingEvidenceCount > 0) {
    return "challenged";
  }
  if (theory.status === "strengthening" && theory.contradictingEvidenceCount === 0) {
    return "confirmed";
  }
  return "unclear";
}

function theoryEntryIds(theory: Theory): Set<string> {
  return new Set([
    ...theory.supportingEvidence.map((q) => q.entryId),
    ...theory.contradictingEvidence.map((q) => q.entryId),
  ]);
}

function classifyTheoryAccuracy(
  theory: Theory,
  predictionByCandidateId: Map<string, PredictionReviewItem>,
  outcomesByInsightId: Map<string, InsightOutcomeResponse>,
  reviewIdFromTheory: string | null,
): ArchiveBeliefAccuracyRow {
  const statuses: ArchiveBeliefAccuracyStatus[] = [];
  let detail: string | null = null;

  if (theory.id.startsWith("theory:prediction:")) {
    const candidateId = theory.id.slice("theory:prediction:".length);
    const prediction = predictionByCandidateId.get(candidateId);
    const fromPrediction = statusFromPrediction(prediction);
    if (fromPrediction) {
      statuses.push(fromPrediction.status);
      detail = fromPrediction.detail;
    }
  }

  const outcome =
    outcomesByInsightId.get(theory.id) ??
    (reviewIdFromTheory ? outcomesByInsightId.get(reviewIdFromTheory) : undefined);
  const fromOutcome = statusFromInsightOutcome(outcome);
  if (fromOutcome) statuses.push(fromOutcome);

  if (reviewIdFromTheory) {
    const commitment = readAllExperimentCommitments().find(
      (row) => row.reviewId === reviewIdFromTheory && row.followUpAnswer,
    );
    if (commitment?.followUpAnswer === "caught_earlier") {
      statuses.push("confirmed");
    } else if (commitment?.followUpAnswer === "no") {
      statuses.push("challenged");
    } else if (commitment?.followUpAnswer) {
      statuses.push("unclear");
    }
  }

  const entryIds = theoryEntryIds(theory);
  for (const followup of readArchiveFollowupAnswers()) {
    if (!entryIds.has(followup.entryId)) continue;
    if (followup.answer === "yes") statuses.push("confirmed");
    else if (followup.answer === "no") statuses.push("challenged");
    else statuses.push("unclear");
  }

  statuses.push(statusFromTheorySignals(theory));

  const status = mergeStatuses(statuses);
  const personal = theoryToPersonalTheory(theory);
  const row: ArchiveBeliefAccuracyRow = {
    theoryId: theory.id,
    belief: personal.hypothesis,
    status,
    statusLabel: ARCHIVE_ACCURACY_STATUS_LABEL[status],
    detail,
  };

  if (row.detail) assertNoCertaintyLanguage(row.detail);
  assertNoCertaintyLanguage(row.belief);
  return row;
}

function blindSpotReviewId(theoryId: string): string | null {
  if (!theoryId.startsWith("theory:blind_spot:")) return null;
  return theoryId.slice("theory:blind_spot:".length);
}

function pickBeliefsToScore(theories: Theory[]): Theory[] {
  const active = theories.filter(
    (t) =>
      t.status === "active" ||
      t.status === "strengthening" ||
      t.status === "weakening" ||
      t.id.startsWith("theory:prediction:"),
  );
  const pool = active.length > 0 ? active : theories;
  return pool
    .slice()
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, MAX_BELIEFS);
}

export function buildArchiveAccuracyView(
  entriesInput?: JournalEntry[],
): ArchiveAccuracyView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length < 2) return null;

  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const acceleration = buildBlindSpotAccelerationReport(entries);

  const predictionByCandidateId = new Map<string, PredictionReviewItem>();
  for (const item of acceleration.predictionReview.items) {
    predictionByCandidateId.set(item.candidate.id, item);
  }

  const outcomesByInsightId = new Map<string, InsightOutcomeResponse>();
  for (const event of readAllInsightOutcomeEvents()) {
    if (!event.outcome || !event.respondedAt) continue;
    outcomesByInsightId.set(event.insightId, event.outcome);
  }

  const theories = pickBeliefsToScore(report.all);
  const beliefs = theories.map((theory) =>
    classifyTheoryAccuracy(
      theory,
      predictionByCandidateId,
      outcomesByInsightId,
      blindSpotReviewId(theory.id),
    ),
  );

  if (beliefs.length === 0) return null;
  return { beliefs };
}
