import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { SESSION_MOVEMENT_COPY } from "@/lib/archive/session-movement-summary-copy";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { clampConfidence } from "@/lib/theories/theory-confidence-movement";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { SessionMovementKind, SessionMovementSummaryView } from "@/types/session-movement-summary";
import type { JournalEntry } from "@/types/journal";
import type { Theory, TheoryStatus } from "@/types/theory";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function base(
  kind: SessionMovementKind,
  headline: string,
  reason: string,
  detailLine?: string,
  theoryId?: string,
): SessionMovementSummaryView {
  return {
    id: newId("sms"),
    kind,
    headline,
    detailLine,
    reason,
    theoryId,
  };
}

function statusLabel(status: TheoryStatus): string {
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

export function buildSessionMovementSummary(
  entriesInput?: JournalEntry[],
  options?: { newEntryId?: string; browseSurface?: boolean },
): SessionMovementSummaryView | null {
  const entriesAfter = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entriesAfter.length === 0) return null;

  const newEntryId = options?.newEntryId;
  const entriesBefore = newEntryId
    ? entriesAfter.filter((e) => e.id !== newEntryId)
    : entriesAfter.length > 1
      ? entriesAfter.slice(0, -1)
      : [];

  const valueBefore = buildArchiveValueSnapshot(entriesBefore);
  const valueAfter = buildArchiveValueSnapshot(entriesAfter);
  const reportBefore = buildTheoryTrackerReport(entriesBefore, { persistSnapshots: false });
  const reportAfter = buildTheoryTrackerReport(entriesAfter, { persistSnapshots: true });
  const lead = reportAfter.all[0];
  const leadBefore = lead ? reportBefore.all.find((t) => t.id === lead.id) : undefined;

  if (lead && leadBefore && leadBefore.status !== lead.status) {
    return base(
      "belief_changed",
      SESSION_MOVEMENT_COPY.beliefChanged,
      `Status moved from ${statusLabel(leadBefore.status)} to ${statusLabel(lead.status)}.`,
      `${statusLabel(leadBefore.status)} → ${statusLabel(lead.status)}`,
      lead.id,
    );
  }

  if (lead && lead.previousConfidence !== undefined && Math.abs(lead.confidenceDelta) >= 1) {
    const prev = clampConfidence(lead.previousConfidence);
    const curr = clampConfidence(lead.confidence);
    return base(
      "confidence_moved",
      SESSION_MOVEMENT_COPY.confidenceMoved,
      "The archive re-weighted evidence for a working belief.",
      `${prev}% → ${curr}%`,
      lead.id,
    );
  }

  const beforeSupport = leadBefore?.supportingEvidenceCount ?? valueBefore.reflectionCount;
  const afterSupport = lead?.supportingEvidenceCount ?? valueAfter.reflectionCount;
  if (afterSupport > beforeSupport) {
    return base(
      "new_evidence_added",
      SESSION_MOVEMENT_COPY.newEvidence,
      lead
        ? `Supporting reflections for this thread: ${beforeSupport} → ${afterSupport}.`
        : `Your archive now holds ${valueAfter.reflectionCount} reflection${valueAfter.reflectionCount === 1 ? "" : "s"} to compare.`,
      lead ? `${beforeSupport} → ${afterSupport} supporting reflections` : undefined,
      lead?.id,
    );
  }

  if (
    valueAfter.contradictionCount > valueBefore.contradictionCount ||
    (leadBefore &&
      lead &&
      lead.contradictingEvidenceCount > (leadBefore.contradictingEvidenceCount ?? 0))
  ) {
    return base(
      "contradiction_appeared",
      SESSION_MOVEMENT_COPY.contradiction,
      "Your archive now contains evidence pointing in two directions.",
      undefined,
      lead?.id,
    );
  }

  if (lead && (lead.status === "weakening" || (lead.confidenceDelta < 0 && lead.previousConfidence !== undefined))) {
    return base(
      "belief_weakened",
      SESSION_MOVEMENT_COPY.beliefWeakened,
      "Recent reflections may pull against an earlier working view.",
      lead.previousConfidence !== undefined
        ? `${clampConfidence(lead.previousConfidence)}% → ${clampConfidence(lead.confidence)}%`
        : statusLabel(lead.status),
      lead.id,
    );
  }

  if (
    lead &&
    (lead.status === "strengthening" || (lead.confidenceDelta > 0 && lead.previousConfidence !== undefined))
  ) {
    return base(
      "belief_strengthened",
      SESSION_MOVEMENT_COPY.beliefStrengthened,
      "Repeated evidence may be reinforcing a working belief.",
      lead.previousConfidence !== undefined
        ? `${clampConfidence(lead.previousConfidence)}% → ${clampConfidence(lead.confidence)}%`
        : statusLabel(lead.status),
      lead.id,
    );
  }

  const browse = options?.browseSurface === true;
  return base(
    "comparison_point",
    browse ? SESSION_MOVEMENT_COPY.comparisonBrowse : SESSION_MOVEMENT_COPY.comparisonPoint,
    browse
      ? "Open Discover to see what your archive currently believes."
      : "Patterns are judged against your history, not a single mood.",
    valueAfter.reflectionCount >= 2
      ? `${valueAfter.reflectionCount} reflections in archive`
      : "1 reflection in archive",
    lead?.id,
  );
}
