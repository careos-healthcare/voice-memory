import { FORBIDDEN_THEORY_OUTPUT } from "@/lib/theories/theory-copy";
import type { Theory, TheoryChangeItem, TheoryStatus } from "@/types/theory";

export type TheoryDisplayStatus =
  | "strengthening"
  | "weakening"
  | "unresolved"
  | "under_review"
  | "resolved"
  | "retired";

const MIN_REFLECTIONS_TO_TEST = 3;

export interface TheoryUncertaintyView {
  supportingCount: number;
  contradictingCount: number;
  missingEvidenceCount: number;
  missingEvidenceNote: string;
  confidence: number;
  displayStatus: TheoryDisplayStatus;
  displayStatusLabel: string;
  panelTitle: string;
  panelLead: string;
}

export const THEORY_UNCERTAINTY_COPY = {
  panelTitle: "Theory under review",
  panelLead: "This theory is still being tested by your archive.",
  supportingLabel: "Evidence (supporting)",
  contradictingLabel: "Evidence (contradicting)",
  missingLabel: "Missing / unknown",
  confidenceLabel: "Evidence balance",
  statusLabel: "Archive read",
  displayStatusLabels: {
    strengthening: "Strengthening",
    weakening: "Weakening",
    unresolved: "Unresolved",
    under_review: "Under review",
    resolved: "May no longer fit",
    retired: "Retired",
  } as const,
} as const;

export interface TheoryUncertaintyInput {
  supportingEvidenceCount: number;
  contradictingEvidenceCount: number;
  confidence: number;
  status: TheoryStatus;
  supportingQuoteCount?: number;
  contradictingQuoteCount?: number;
}

function missingEvidenceNote(input: TheoryUncertaintyInput, missingCount: number): string {
  if (missingCount > 0) {
    return `${missingCount} more reflection${missingCount === 1 ? "" : "s"} may help test this pattern.`;
  }
  if (input.contradictingEvidenceCount === 0 && input.supportingEvidenceCount > 0) {
    return "No opposing reflections captured in range yet — one-sided so far.";
  }
  if (input.contradictingEvidenceCount > 0 && input.supportingEvidenceCount > 0) {
    return "Supporting and contradicting reflections both appear — still open.";
  }
  return "More reflections over time may narrow or shift this.";
}

export function resolveTheoryDisplayStatus(
  status: TheoryStatus,
  input: TheoryUncertaintyInput,
): TheoryDisplayStatus {
  if (status === "resolved") return "resolved";
  if (status === "retired") return "retired";
  if (status === "strengthening") return "strengthening";
  if (status === "weakening") return "weakening";

  const mixed =
    input.contradictingEvidenceCount > 0 &&
    input.supportingEvidenceCount > 0 &&
    input.confidence < 55;
  if (mixed) return "unresolved";

  if (status === "active" && input.supportingEvidenceCount < MIN_REFLECTIONS_TO_TEST) {
    return "under_review";
  }

  if (status === "active" && input.confidence < 50) return "unresolved";

  return "under_review";
}

/** Cautious uncertainty summary for a theory or change item. */
export function buildTheoryUncertaintyView(
  input: TheoryUncertaintyInput,
): TheoryUncertaintyView {
  const supportingCount = input.supportingEvidenceCount;
  const contradictingCount = input.contradictingEvidenceCount;
  const missingEvidenceCount = Math.max(0, MIN_REFLECTIONS_TO_TEST - supportingCount);

  const displayStatus = resolveTheoryDisplayStatus(input.status, input);
  const displayStatusLabel = THEORY_UNCERTAINTY_COPY.displayStatusLabels[displayStatus];

  const panelLead = THEORY_UNCERTAINTY_COPY.panelLead;
  assertCautiousCopy(panelLead);

  return {
    supportingCount,
    contradictingCount,
    missingEvidenceCount,
    missingEvidenceNote: missingEvidenceNote(input, missingEvidenceCount),
    confidence: input.confidence,
    displayStatus,
    displayStatusLabel,
    panelTitle: THEORY_UNCERTAINTY_COPY.panelTitle,
    panelLead,
  };
}

export function buildTheoryUncertaintyFromTheory(theory: Theory): TheoryUncertaintyView {
  return buildTheoryUncertaintyView({
    supportingEvidenceCount: theory.supportingEvidenceCount,
    contradictingEvidenceCount: theory.contradictingEvidenceCount,
    confidence: theory.confidence,
    status: theory.status,
    supportingQuoteCount: theory.supportingEvidence.length,
    contradictingQuoteCount: theory.contradictingEvidence.length,
  });
}

export function buildTheoryUncertaintyFromChangeItem(
  item: TheoryChangeItem,
): TheoryUncertaintyView {
  return buildTheoryUncertaintyView({
    supportingEvidenceCount: item.supportingEvidenceCount,
    contradictingEvidenceCount: item.contradictingEvidenceCount,
    confidence: item.confidence,
    status: item.status,
  });
}

function assertCautiousCopy(text: string): void {
  if (FORBIDDEN_THEORY_OUTPUT.test(text)) {
    throw new Error("Theory uncertainty copy failed restraint check");
  }
}
