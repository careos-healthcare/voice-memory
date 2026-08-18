import { buildBlindSpotAccelerationReport } from "@/lib/blind-spots/blind-spot-acceleration";
import {
  buildCostEvidence,
  formatCostEvidenceLine,
} from "@/lib/blind-spots/cost-evidence";
import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import type { Theory, TheoryEvidenceBaselineEntry } from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

const BASELINE_VERSION = 2;

function entryIdsFromQuotes(quotes: Theory["supportingEvidence"]): string[] {
  return [...new Set(quotes.map((q) => q.entryId))];
}

function blindSpotReviewIdFromTheoryId(theoryId: string): string | null {
  if (!theoryId.startsWith("theory:blind_spot:")) return null;
  return theoryId.slice("theory:blind_spot:".length);
}

function predictionCandidateIdFromTheoryId(theoryId: string): string | null {
  if (!theoryId.startsWith("theory:prediction:")) return null;
  return theoryId.slice("theory:prediction:".length);
}

/** One-time context per feed build — reuses acceleration report. */
export function buildDiscoverEvidenceContext(entries: JournalEntry[]) {
  const eligible = entries.filter((e) => e.reflectionPending !== true);
  const acceleration = buildBlindSpotAccelerationReport(entries);

  const blindSpotReview =
    acceleration.mainReview.kind === "ready" ? acceleration.mainReview.review : null;

  const predictionByCandidateId = new Map(
    acceleration.predictionReview.items.map((item) => [item.candidate.id, item]),
  );

  return { eligible, blindSpotReview, predictionByCandidateId };
}

export type DiscoverEvidenceContext = ReturnType<typeof buildDiscoverEvidenceContext>;

export function theoryToEvidenceBaseline(
  theory: Theory,
  entries: JournalEntry[],
  context: DiscoverEvidenceContext,
): TheoryEvidenceBaselineEntry {
  const supportingEntryIds = entryIdsFromQuotes(theory.supportingEvidence);
  const contradictingEntryIds = entryIdsFromQuotes(theory.contradictingEvidence);
  const lifeAreas = linkedAreasForEntries(context.eligible, supportingEntryIds);

  let costEvidenceLines: string[] = [];
  if (theory.source === "blind_spot" && context.blindSpotReview) {
    const reviewId = blindSpotReviewIdFromTheoryId(theory.id);
    if (reviewId === context.blindSpotReview.reviewId) {
      const counts = buildCostEvidence(supportingEntryIds, context.eligible);
      costEvidenceLines = formatCostEvidenceLine(counts);
    }
  }

  let predictionOutcomeKey: string | undefined;
  if (theory.source === "prediction") {
    const candidateId = predictionCandidateIdFromTheoryId(theory.id);
    const item = candidateId ? context.predictionByCandidateId.get(candidateId) : undefined;
    if (item) {
      predictionOutcomeKey = `${item.candidate.id}:${item.outcomeStatus}:${item.outcomeSummary}`;
    }
  }

  return {
    id: theory.id,
    confidence: theory.confidence,
    status: theory.status,
    statement: theory.statement,
    source: theory.source,
    supportingEntryIds,
    contradictingEntryIds,
    lifeAreas,
    costEvidenceLines,
    predictionOutcomeKey,
  };
}

export function migrateLegacyBaselineTheory(
  raw: Record<string, unknown>,
): TheoryEvidenceBaselineEntry | null {
  if (Array.isArray(raw.supportingEntryIds)) {
    return raw as unknown as TheoryEvidenceBaselineEntry;
  }
  if (typeof raw.id !== "string") return null;
  return {
    id: raw.id,
    confidence: typeof raw.confidence === "number" ? raw.confidence : 0,
    status: (raw.status as TheoryEvidenceBaselineEntry["status"]) ?? "active",
    statement: typeof raw.statement === "string" ? raw.statement : "",
    source: (raw.source as TheoryEvidenceBaselineEntry["source"]) ?? "pattern",
    supportingEntryIds: Array.isArray(raw.supportingEntryIds)
      ? (raw.supportingEntryIds as string[])
      : [],
    contradictingEntryIds: Array.isArray(raw.contradictingEntryIds)
      ? (raw.contradictingEntryIds as string[])
      : [],
    lifeAreas: Array.isArray(raw.lifeAreas) ? (raw.lifeAreas as string[]) : [],
    costEvidenceLines: Array.isArray(raw.costEvidenceLines)
      ? (raw.costEvidenceLines as string[])
      : [],
    predictionOutcomeKey:
      typeof raw.predictionOutcomeKey === "string" ? raw.predictionOutcomeKey : undefined,
  };
}

export const DISCOVER_BASELINE_VERSION = BASELINE_VERSION;
