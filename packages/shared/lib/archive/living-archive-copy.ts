import type { ArchiveLivingStatus } from "@/types/living-archive";

export const ARCHIVE_STATUS_CARD_TITLE = "Archive Status";

export const ARCHIVE_LIVING_STATUS_LABEL: Record<ArchiveLivingStatus, string> = {
  learning: "Learning",
  investigating: "Investigating",
  strengthening: "Strengthening",
  uncertain: "Uncertain",
  revising: "Revising",
  stable: "Stable",
};

export const ARCHIVE_LIVING_STATUS_LINE: Record<ArchiveLivingStatus, string> = {
  learning: "Your archive is still gathering a working belief.",
  investigating: "New evidence is still arriving.",
  strengthening: "This belief is gaining support.",
  uncertain: "The archive is weighing conflicting evidence.",
  revising: "The archive is reconsidering one belief.",
  stable: "This belief has remained consistent.",
};

export const ARCHIVE_ACTIVITY_SECTION = {
  statusChanges: "Status Changes",
  beliefChanges: "Belief Changes",
  evidenceChanges: "Evidence Changes",
  openQuestions: "Open Questions",
} as const;

export const ARCHIVE_MEMORY_TITLE = "How this belief has shifted";
