import { readDiscoverBaseline, readDiscoverLastVisitAt } from "@/lib/discover/discover-visit";
import {
  buildDiscoverEvidenceContext,
  theoryToEvidenceBaseline,
} from "@/lib/discover/theory-evidence-snapshot";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import type { EvidenceFeedReport, EvidenceMovement } from "@/types/evidence-feed";
import type {
  Theory,
  TheoryEvidenceBaselineEntry,
  TheoryEvidenceQuote,
} from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

function newQuotes(
  current: TheoryEvidenceQuote[],
  baselineIds: Set<string>,
): TheoryEvidenceQuote[] {
  return current.filter((q) => !baselineIds.has(q.entryId));
}

/** Compare current theories to visit baseline — evidence movement only. */
export function buildEvidenceFeed(entries: JournalEntry[]): EvidenceFeedReport {
  const baseline = readDiscoverBaseline();
  const lastVisitAt = readDiscoverLastVisitAt();
  const context = buildDiscoverEvidenceContext(entries);
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: true });
  const current = report.all;

  if (!baseline) {
    return {
      generatedAt: new Date().toISOString(),
      hasBaseline: false,
      lastVisitAt,
      movements: [],
      totalMovements: 0,
    };
  }

  const baselineById = new Map(baseline.theories.map((t) => [t.id, t]));
  const movements: EvidenceMovement[] = [];

  for (const theory of current) {
    const prev = baselineById.get(theory.id);
    const snapshot = theoryToEvidenceBaseline(theory, entries, context);

    const base = baselineSets(prev);

    const newSupporting = newQuotes(theory.supportingEvidence, base.supporting);
    if (newSupporting.length > 0) {
      movements.push({
        kind: "new_supporting",
        theoryId: theory.id,
        theoryStatement: theory.statement,
        source: theory.source,
        summary:
          newSupporting.length === 1
            ? "One new supporting reflection since your last visit."
            : `${newSupporting.length} new supporting reflections since your last visit.`,
        quotes: newSupporting,
      });
    }

    const newContradicting = newQuotes(theory.contradictingEvidence, base.contradicting);
    if (newContradicting.length > 0) {
      movements.push({
        kind: "new_contradicting",
        theoryId: theory.id,
        theoryStatement: theory.statement,
        source: theory.source,
        summary:
          newContradicting.length === 1
            ? "One new contradicting reflection since your last visit."
            : `${newContradicting.length} new contradicting reflections since your last visit.`,
        quotes: newContradicting,
      });
    }

    if (prev !== undefined) {
      const delta = theory.confidence - prev.confidence;
      if (delta !== 0) {
        const direction = delta > 0 ? "rose" : "fell";
        movements.push({
          kind: "confidence_movement",
          theoryId: theory.id,
          theoryStatement: theory.statement,
          source: theory.source,
          summary: `Confidence ${direction} from ${prev.confidence} to ${theory.confidence}.`,
          quotes: [],
          confidenceDelta: delta,
          previousConfidence: prev.confidence,
          currentConfidence: theory.confidence,
        });
      }
    }

    const newAreas = snapshot.lifeAreas.filter((a) => !base.lifeAreas.has(a));
    if (newAreas.length > 0 && prev) {
      movements.push({
        kind: "new_life_area",
        theoryId: theory.id,
        theoryStatement: theory.statement,
        source: theory.source,
        summary: `Pattern may now span: ${newAreas.join(", ")}.`,
        quotes: [],
        lifeAreas: newAreas,
      });
    }

    const newCostLines = snapshot.costEvidenceLines.filter((line) => !base.costLines.has(line));
    if (newCostLines.length > 0) {
      movements.push({
        kind: "new_cost_evidence",
        theoryId: theory.id,
        theoryStatement: theory.statement,
        source: theory.source,
        summary: "New possible cost signals in later reflections.",
        quotes: [],
        costEvidenceLines: newCostLines,
      });
    }

    if (
      snapshot.predictionOutcomeKey &&
      snapshot.predictionOutcomeKey !== base.predictionKey
    ) {
      const candidateId = theory.id.replace("theory:prediction:", "");
      const item = context.predictionByCandidateId.get(candidateId);
      movements.push({
        kind: "prediction_outcome",
        theoryId: theory.id,
        theoryStatement: theory.statement,
        source: theory.source,
        summary: item?.outcomeSummary ?? "Prediction outcome updated since your last visit.",
        quotes: theory.supportingEvidence.slice(-1),
        predictionOutcomeSummary: item?.outcomeSummary,
      });
    }
  }

  const kindOrder: Record<EvidenceMovement["kind"], number> = {
    new_supporting: 0,
    new_contradicting: 1,
    confidence_movement: 2,
    new_life_area: 3,
    new_cost_evidence: 4,
    prediction_outcome: 5,
  };

  movements.sort((a, b) => kindOrder[a.kind] - kindOrder[b.kind]);

  return {
    generatedAt: new Date().toISOString(),
    hasBaseline: true,
    lastVisitAt: baseline.savedAt ?? lastVisitAt,
    movements,
    totalMovements: movements.length,
  };
}

function baselineSets(prev: TheoryEvidenceBaselineEntry | undefined) {
  if (!prev) {
    return {
      supporting: new Set<string>(),
      contradicting: new Set<string>(),
      lifeAreas: new Set<string>(),
      costLines: new Set<string>(),
      predictionKey: undefined as string | undefined,
    };
  }
  return {
    supporting: new Set(prev.supportingEntryIds),
    contradicting: new Set(prev.contradictingEntryIds),
    lifeAreas: new Set(prev.lifeAreas),
    costLines: new Set(prev.costEvidenceLines),
    predictionKey: prev.predictionOutcomeKey,
  };
}
