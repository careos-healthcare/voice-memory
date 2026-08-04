import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildBlindSpotAccelerationReport } from "@/lib/blind-spots/blind-spot-acceleration";
import { readAllExperimentCommitments } from "@/lib/blind-spots/blind-spot-experiment-commitment";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { BeliefDossierView } from "@/types/belief-dossier";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

export const BELIEF_DOSSIER_TITLE = "Belief dossier";
export const BELIEF_DOSSIER_LEAD =
  "This is the current case your archive can support.";
export const BELIEF_DOSSIER_WHAT_WOULD_CHANGE_TITLE =
  "What would change this belief?";

function formatWhen(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(iso));
}

function blindSpotReviewIdFromTheoryId(theoryId: string): string | null {
  if (!theoryId.startsWith("theory:blind_spot:")) return null;
  return theoryId.slice("theory:blind_spot:".length);
}

function buildWhatWouldChangeLines(
  belief: NonNullable<ReturnType<typeof buildArchiveBeliefView>>,
  theory: Theory | null,
): string[] {
  const lines: string[] = [];
  const seen = new Set<string>();

  const push = (text: string) => {
    const t = text.trim();
    if (!t || seen.has(t)) return;
    seen.add(t);
    lines.push(t);
  };

  if (belief.evidence.contradictingQuotes.length > 0) {
    push("Contradicting evidence would reduce confidence.");
  }
  if (belief.status === "weakening") {
    push("More saved moments that do not repeat the pattern would weaken it.");
  }
  if (belief.status === "strengthening" || belief.status === "under_review") {
    push(
      "More saved moments where the same pattern holds without contradiction would strengthen it.",
    );
  }
  if (belief.evidence.lifeAreas.length >= 2) {
    push("A repeated version of this pattern in another area would strengthen it.");
  } else if (belief.evidence.lifeAreas.length === 1) {
    push(
      `Evidence from outside ${belief.evidence.lifeAreas[0]!.toLowerCase()} would change how far the archive generalizes.`,
    );
  }
  if (belief.evidence.costEvidenceLines.length > 0) {
    push("New cost signals in saved moments would shift how seriously the archive weighs it.");
  }
  if (belief.evidence.predictionFailureLines.length > 0) {
    push("Saved moments that match what you expected would soften a failed-prediction read.");
  }
  if (theory && theory.contradictingEvidenceCount === 0 && belief.confidence >= 70) {
    push(
      "More saved moments where criticism does not lead to spiralling would weaken a high-confidence read.",
    );
  }

  return lines.slice(0, 5);
}

export function buildBeliefDossier(
  entriesInput?: JournalEntry[],
): BeliefDossierView | null {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const history = readBeliefTimelineHistory(belief.theoryId);
  const first = history[0];
  const last = history[history.length - 1];

  const report = buildBlindSpotAccelerationReport(entries);
  const reviewId = blindSpotReviewIdFromTheoryId(belief.theoryId);
  let relatedBlindSpotHeadline: string | null = null;
  if (
    reviewId &&
    report.mainReview.kind === "ready" &&
    report.mainReview.review.reviewId === reviewId
  ) {
    relatedBlindSpotHeadline = report.mainReview.review.headline;
  }

  const latestExperiment = readAllExperimentCommitments()[0];
  const relatedExperimentLine = latestExperiment?.experimentText?.trim()
    ? latestExperiment.experimentText.trim()
    : null;

  return {
    theoryId: belief.theoryId,
    belief: belief.belief,
    confidence: belief.confidence,
    status: belief.status,
    statusLabel: belief.statusLabel,
    firstAppearedLabel: first ? `${first.periodLabel} · ${first.note}` : null,
    lastChangedLabel: last
      ? `${last.periodLabel} · ${last.note}`
      : belief.changeLines[0]?.text.replace(/^\+\s*/, "") ?? null,
    evidence: belief.evidence,
    lifeAreas: belief.evidence.lifeAreas,
    relatedBlindSpotHeadline,
    relatedExperimentLine,
    whatWouldChangeLines: buildWhatWouldChangeLines(belief, null),
  };
}
