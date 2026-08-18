import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export const WHAT_IS_MY_ARCHIVE_BODY = [
  "Your archive is building a view of you.",
  "Every reflection becomes evidence.",
  "Over time the archive forms beliefs.",
  "Those beliefs strengthen, weaken, or disappear.",
] as const;

export type ArchiveUnderstandingStageId =
  | "collecting_evidence"
  | "testing_beliefs"
  | "tracking_changes";

export const ARCHIVE_UNDERSTANDING_STAGES: ReadonlyArray<{
  id: ArchiveUnderstandingStageId;
  reflectionRange: string;
  label: string;
}> = [
  { id: "collecting_evidence", reflectionRange: "Reflection 1–2", label: "Collecting evidence" },
  { id: "testing_beliefs", reflectionRange: "Reflection 3–4", label: "Testing beliefs" },
  { id: "tracking_changes", reflectionRange: "Reflection 5+", label: "Tracking belief changes" },
];

export function stageIdForReflectionCount(count: number): ArchiveUnderstandingStageId {
  if (count <= 2) return "collecting_evidence";
  if (count <= 4) return "testing_beliefs";
  return "tracking_changes";
}

export interface WhatIsMyArchiveView {
  bodyLines: readonly string[];
  currentStage: (typeof ARCHIVE_UNDERSTANDING_STAGES)[number];
  reflectionCount: number;
}

export function buildWhatIsMyArchiveView(
  entriesInput?: JournalEntry[],
): WhatIsMyArchiveView {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const reflectionCount = entries.length;
  const stageId = stageIdForReflectionCount(reflectionCount);
  const currentStage =
    ARCHIVE_UNDERSTANDING_STAGES.find((s) => s.id === stageId) ??
    ARCHIVE_UNDERSTANDING_STAGES[0]!;

  return {
    bodyLines: WHAT_IS_MY_ARCHIVE_BODY,
    currentStage,
    reflectionCount,
  };
}
