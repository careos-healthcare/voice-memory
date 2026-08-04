import { ARCHIVE_EMOTIONAL } from "@/lib/archive/archive-emotional-copy";
import type { TheoryStatus } from "@/types/theory";

export type TheoryMomentum = "strengthening" | "weakening" | "new" | "unresolved";

export interface WhatChangedInput {
  status: TheoryStatus;
  confidenceDelta: number;
  supportingEvidenceCount: number;
  contradictingEvidenceCount: number;
  newSupportingSinceLast?: number;
  isFirstSnapshot: boolean;
  resolutionNote?: string;
}

export function buildWhatChanged(input: WhatChangedInput): string[] {
  const lines: string[] = [];

  if (input.resolutionNote) {
    lines.push(input.resolutionNote);
  }

  if (input.isFirstSnapshot && input.status === "active") {
    lines.push(
      `This is new because it appeared across ${Math.max(2, input.supportingEvidenceCount)} recent moments.`,
    );
    return lines.slice(0, 3);
  }

  if (input.status === "resolved" || input.status === "retired") {
    if (lines.length === 0) {
      lines.push(ARCHIVE_EMOTIONAL.theoryRetired);
    }
    return lines.slice(0, 3);
  }

  if (input.confidenceDelta >= 5) {
    lines.push(ARCHIVE_EMOTIONAL.confidenceIncreased);
  } else if (input.confidenceDelta <= -5) {
    lines.push(ARCHIVE_EMOTIONAL.theoryWeakened);
  }

  if (input.status === "active") {
    if (
      input.contradictingEvidenceCount > 0 &&
      input.supportingEvidenceCount > 0 &&
      input.supportingEvidenceCount < 3
    ) {
      lines.push("This stayed open because there is not enough repeated evidence yet.");
    } else if (
      input.contradictingEvidenceCount > 0 &&
      input.supportingEvidenceCount > 0
    ) {
      lines.push("This stayed open because evidence is mixed.");
    }
  }

  if (input.status === "strengthening" && lines.length === 0) {
    lines.push(ARCHIVE_EMOTIONAL.confidenceIncreased);
  }

  if (input.status === "weakening" && lines.length === 0) {
    lines.push(ARCHIVE_EMOTIONAL.theoryWeakened);
  }

  if (input.status === "active" && lines.length === 0 && input.isFirstSnapshot) {
    lines.push(
      `This is new because it appeared across ${Math.max(2, input.supportingEvidenceCount)} recent moments.`,
    );
  }

  return lines.slice(0, 3);
}

/** Pre-resolution momentum from confidence trajectory and mixed evidence. */
export function resolveTheoryMomentum(input: {
  confidence: number;
  confidenceDelta: number;
  isFirstSnapshot: boolean;
  createdAt: string;
  supportingCount: number;
  contradictingCount: number;
}): TheoryMomentum {
  const createdMs = new Date(input.createdAt).getTime();
  const daysSinceCreated = (Date.now() - createdMs) / (1000 * 60 * 60 * 24);

  const mixed =
    input.supportingCount > 0 &&
    input.contradictingCount > 0 &&
    input.contradictingCount / (input.supportingCount + input.contradictingCount) >=
      0.35;

  if (
    input.confidence < 42 ||
    mixed ||
    (input.supportingCount < 3 && input.contradictingCount > 0)
  ) {
    return "unresolved";
  }

  if (input.isFirstSnapshot || daysSinceCreated <= 14) {
    if (input.confidenceDelta > 3) return "strengthening";
    return "new";
  }

  if (input.confidenceDelta >= 4) return "strengthening";
  if (input.confidenceDelta <= -4) return "weakening";
  if (input.confidence < 50) return "unresolved";

  return input.confidenceDelta >= 0 ? "strengthening" : "weakening";
}
