import {
  ArchiveMaturityEngine,
  buildArchiveMaturityEngineInput,
} from "@/lib/archive/archive-maturity-engine";
import { ARCHIVE_MATURITY_INCREASED_LABEL } from "@/lib/archive/archive-progress-copy";
import {
  ARCHIVE_SUCCESS_BY_KIND,
  ARCHIVE_SUCCESS_HEADLINE,
} from "@/lib/design/archive-success-copy";
import { buildSessionMovementSummary } from "@/lib/archive/session-movement-summary";
import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { SessionMovementKind } from "@/types/session-movement-summary";

export type ReflectionImpactKind =
  | "supported_belief"
  | "challenged_belief"
  | "new_life_area"
  | "increased_confidence"
  | "reduced_confidence"
  | "comparison_point";

export const REFLECTION_IMPACT_RECEIPT_LABEL: Record<ReflectionImpactKind, string> = {
  supported_belief: `${ARCHIVE_SUCCESS_HEADLINE} ${ARCHIVE_SUCCESS_BY_KIND.supported_belief}`,
  challenged_belief: `${ARCHIVE_SUCCESS_HEADLINE} ${ARCHIVE_SUCCESS_BY_KIND.challenged_belief}`,
  new_life_area: `${ARCHIVE_SUCCESS_HEADLINE} ${ARCHIVE_SUCCESS_BY_KIND.new_life_area}`,
  increased_confidence: `${ARCHIVE_SUCCESS_HEADLINE} ${ARCHIVE_SUCCESS_BY_KIND.increased_confidence}`,
  reduced_confidence: `${ARCHIVE_SUCCESS_HEADLINE} ${ARCHIVE_SUCCESS_BY_KIND.reduced_confidence}`,
  comparison_point: `${ARCHIVE_SUCCESS_HEADLINE} ${ARCHIVE_SUCCESS_BY_KIND.comparison_point}`,
};

export interface ReflectionImpactReceiptView {
  kind: ReflectionImpactKind;
  label: string;
  maturityDelta: number;
  maturityIncreaseLabel: string | null;
  displayLabel: string;
}

function kindFromMovement(
  movementKind: SessionMovementKind,
  entriesBefore: JournalEntry[],
  entriesAfter: JournalEntry[],
  newEntryId: string,
): ReflectionImpactKind {
  const reportBefore = buildTheoryTrackerReport(entriesBefore, { persistSnapshots: false });
  const reportAfter = buildTheoryTrackerReport(entriesAfter, { persistSnapshots: false });
  const leadAfter = reportAfter.all[0];
  const leadBefore = leadAfter
    ? reportBefore.all.find((t) => t.id === leadAfter.id)
    : undefined;

  if (movementKind === "contradiction_appeared") return "challenged_belief";
  if (movementKind === "belief_weakened") return "reduced_confidence";
  if (movementKind === "belief_strengthened") return "supported_belief";
  if (movementKind === "confidence_moved") {
    if (leadAfter && (leadAfter.confidenceDelta ?? 0) < 0) return "reduced_confidence";
    return "increased_confidence";
  }

  if (leadAfter && leadBefore) {
    const idsBefore = new Set([
      ...leadBefore.supportingEvidence.map((q) => q.entryId),
      ...leadBefore.contradictingEvidence.map((q) => q.entryId),
    ]);
    const idsAfter = [
      ...new Set([
        ...leadAfter.supportingEvidence.map((q) => q.entryId),
        ...leadAfter.contradictingEvidence.map((q) => q.entryId),
        newEntryId,
      ]),
    ];
    const areasBefore = linkedAreasForEntries(entriesBefore, [...idsBefore]);
    const areasAfter = linkedAreasForEntries(entriesAfter, idsAfter);
    if (areasAfter.length > areasBefore.length) return "new_life_area";
  }

  if (movementKind === "new_evidence_added") return "supported_belief";
  return "comparison_point";
}

/** Exactly one impact line after every save — never generic save copy. */
export function buildReflectionImpactReceipt(
  entriesInput?: JournalEntry[],
  newEntryId?: string,
): ReflectionImpactReceiptView {
  const entriesAfter = entriesInput ?? getMemoryEligibleEntries();
  const entryId = newEntryId ?? entriesAfter[entriesAfter.length - 1]?.id;
  const entriesBefore = entryId
    ? entriesAfter.filter((e) => e.id !== entryId)
    : entriesAfter.slice(0, -1);

  const movement = buildSessionMovementSummary(entriesAfter, {
    newEntryId: entryId,
    browseSurface: false,
  });

  const kind = movement
    ? kindFromMovement(movement.kind, entriesBefore, entriesAfter, entryId ?? "")
    : entriesAfter.length <= 1
      ? "comparison_point"
      : "comparison_point";

  const impactLabel = REFLECTION_IMPACT_RECEIPT_LABEL[kind];
  const before = ArchiveMaturityEngine.compute(
    buildArchiveMaturityEngineInput(entriesBefore),
  );
  const after = ArchiveMaturityEngine.compute(
    buildArchiveMaturityEngineInput(entriesAfter),
  );
  const maturityDelta = Math.max(0, after - before);
  const maturityIncreaseLabel =
    maturityDelta > 0 ? ARCHIVE_MATURITY_INCREASED_LABEL(maturityDelta) : null;
  const displayLabel = maturityIncreaseLabel
    ? `${impactLabel} · ${maturityIncreaseLabel}`
    : impactLabel;

  return {
    kind,
    label: impactLabel,
    maturityDelta,
    maturityIncreaseLabel,
    displayLabel,
  };
}
