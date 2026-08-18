import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { ARCHIVE_VALUE_STAGE_COPY } from "@/lib/product/archive-value-copy";
import { ladderLabelForStage } from "@/lib/theories/personal-theory-status";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { readTheorySnapshot } from "@/lib/theories/theory-snapshots";
import { clampConfidence } from "@/lib/theories/theory-confidence-movement";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { ARCHIVE_MOVEMENT_COPY, ARCHIVE_MOVEMENT_EYEBROW } from "@/lib/archive/archive-movement-copy";
import type { ArchiveMovementKind, ArchiveMovementUpdate } from "@/types/archive-movement";
import type { ArchiveValueStage } from "@/types/archive-value";
import type { JournalEntry } from "@/types/journal";
import type { Theory, TheoryStatus } from "@/types/theory";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function newMovementId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `am-${Date.now()}`;
}

function ladderLabel(stage: ArchiveValueStage): string {
  return ARCHIVE_VALUE_STAGE_COPY[stage].ladderLabel;
}

function theoryStatusLabel(status: TheoryStatus): string {
  switch (status) {
    case "strengthening":
      return "Strengthening";
    case "weakening":
      return "Weakening";
    case "resolved":
      return "Resolved";
    case "retired":
      return "Retired";
    default:
      return "Under review";
  }
}

function baseUpdate(
  kind: ArchiveMovementKind,
  headline: string,
  reason: string,
  detailLine?: string,
): ArchiveMovementUpdate {
  return {
    id: newMovementId(),
    kind,
    at: new Date().toISOString(),
    eyebrow: ARCHIVE_MOVEMENT_EYEBROW,
    headline,
    detailLine,
    reason,
  };
}

export function buildArchiveMovementUpdate(
  entriesAfterInput: JournalEntry[],
  options?: { newEntryId?: string },
): ArchiveMovementUpdate {
  const entriesAfter = eligible(entriesAfterInput);
  const newEntryId = options?.newEntryId;
  const entriesBefore = newEntryId
    ? entriesAfter.filter((e) => e.id !== newEntryId)
    : entriesAfter.length > 0
      ? entriesAfter.slice(0, -1)
      : [];

  const valueBefore = buildArchiveValueSnapshot(entriesBefore);
  const valueAfter = buildArchiveValueSnapshot(entriesAfter);

  const reportBefore = buildTheoryTrackerReport(entriesBefore, { persistSnapshots: false });
  const reportAfter = buildTheoryTrackerReport(entriesAfter, { persistSnapshots: true });

  const lead = reportAfter.all[0];
  const leadBefore = lead ? reportBefore.all.find((t) => t.id === lead.id) : undefined;

  if (lead && lead.previousConfidence !== undefined && lead.confidenceDelta !== 0) {
    const prev = clampConfidence(lead.previousConfidence);
    const curr = clampConfidence(lead.confidence);
    const increased = lead.confidenceDelta > 0;
    return baseUpdate(
      "confidence_changed",
      increased
        ? ARCHIVE_MOVEMENT_COPY.confidenceIncreased
        : ARCHIVE_MOVEMENT_COPY.confidenceDecreased,
      increased
        ? ARCHIVE_MOVEMENT_COPY.confidenceReasonSupport
        : ARCHIVE_MOVEMENT_COPY.confidenceReasonWeaken,
      `${prev}% → ${curr}%`,
    );
  }

  const beforeSupport = leadBefore?.supportingEvidenceCount ?? valueBefore.reflectionCount;
  const afterSupport = lead?.supportingEvidenceCount ?? valueAfter.reflectionCount;
  if (afterSupport > beforeSupport) {
    return baseUpdate(
      "evidence_increased",
      ARCHIVE_MOVEMENT_COPY.evidenceAdded,
      afterSupport >= 3
        ? ARCHIVE_MOVEMENT_COPY.evidenceHarderToFool
        : ARCHIVE_MOVEMENT_COPY.confidenceReasonSupport,
      `${beforeSupport} → ${afterSupport} supporting reflections`,
    );
  }

  if (valueBefore.stage !== valueAfter.stage) {
    return baseUpdate(
      "status_changed",
      ARCHIVE_MOVEMENT_COPY.statusChanged,
      ARCHIVE_MOVEMENT_COPY.confidenceReasonSupport,
      `${ladderLabel(valueBefore.stage)} → ${ladderLabel(valueAfter.stage)}`,
    );
  }

  if (leadBefore && lead && leadBefore.status !== lead.status) {
    return baseUpdate(
      "status_changed",
      ARCHIVE_MOVEMENT_COPY.statusChanged,
      ARCHIVE_MOVEMENT_COPY.underReviewReason,
      `${theoryStatusLabel(leadBefore.status)} → ${theoryStatusLabel(lead.status)}`,
    );
  }

  if (valueAfter.crossLifeAreaPatternCount > valueBefore.crossLifeAreaPatternCount) {
    return baseUpdate(
      "new_life_area",
      ARCHIVE_MOVEMENT_COPY.lifeAreaHeadline,
      ARCHIVE_MOVEMENT_COPY.lifeAreaReason,
    );
  }

  if (
    valueAfter.contradictionCount > valueBefore.contradictionCount ||
    (leadBefore &&
      lead &&
      lead.contradictingEvidenceCount > (leadBefore.contradictingEvidenceCount ?? 0))
  ) {
    return baseUpdate(
      "contradiction_detected",
      ARCHIVE_MOVEMENT_COPY.contradictionHeadline,
      ARCHIVE_MOVEMENT_COPY.contradictionReason,
    );
  }

  if (valueAfter.costEvidenceCount > valueBefore.costEvidenceCount) {
    return baseUpdate(
      "cost_evidence_detected",
      ARCHIVE_MOVEMENT_COPY.costHeadline,
      ARCHIVE_MOVEMENT_COPY.costReason,
    );
  }

  if (lead) {
    const snap = readTheorySnapshot(lead.id);
    if (snap && lead.supportingEvidenceCount > 0) {
      return baseUpdate(
        "under_review",
        ARCHIVE_MOVEMENT_COPY.underReviewHeadline,
        ARCHIVE_MOVEMENT_COPY.underReviewReason,
        `${clampConfidence(lead.confidence)}% confidence · ${theoryStatusLabel(lead.status)}`,
      );
    }
  }

  if (valueAfter.reflectionCount >= 1) {
    return baseUpdate(
      "evidence_increased",
      ARCHIVE_MOVEMENT_COPY.evidenceAdded,
      valueAfter.reflectionCount >= 2
        ? ARCHIVE_MOVEMENT_COPY.evidenceHarderToFool
        : ladderLabelForStage(valueAfter.stage),
      valueAfter.reflectionCount === 1
        ? "1 supporting reflection"
        : `${valueBefore.reflectionCount} → ${valueAfter.reflectionCount} reflections in archive`,
    );
  }

  return baseUpdate(
    "under_review",
    ARCHIVE_MOVEMENT_COPY.underReviewHeadline,
    ARCHIVE_MOVEMENT_COPY.underReviewReason,
  );
}

/** Build from current archive (e.g. memory page — uses latest eligible entries). */
export function buildArchiveMovementFromArchive(
  entriesInput?: JournalEntry[],
): ArchiveMovementUpdate {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length === 0) {
    return baseUpdate(
      "under_review",
      ARCHIVE_MOVEMENT_COPY.underReviewHeadline,
      "Your archive is waiting for a first reflection.",
    );
  }
  const last = entries[entries.length - 1]!;
  return buildArchiveMovementUpdate(entries, { newEntryId: last.id });
}
