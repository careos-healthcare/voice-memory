import type { ArchiveMaturityStage } from "@/types/archive-maturity";

export const ARCHIVE_PROGRESS_HEADLINE =
  "Your archive is becoming harder to fool.";

export const ARCHIVE_PROGRESS_MILESTONES: { percent: number; label: string }[] = [
  { percent: 20, label: "Enough moments to compare" },
  { percent: 40, label: "First beliefs under review" },
  { percent: 60, label: "Beliefs shifting with new evidence" },
  { percent: 80, label: "Archive reputation strengthening" },
  { percent: 100, label: "Mature archive — beliefs hard to fool" },
];

export function nextMilestoneForScore(score: number): {
  label: string;
  percent: number;
} {
  const next = ARCHIVE_PROGRESS_MILESTONES.find((m) => m.percent > score);
  if (next) return next;
  return ARCHIVE_PROGRESS_MILESTONES[ARCHIVE_PROGRESS_MILESTONES.length - 1]!;
}

export const ARCHIVE_MATURITY_INCREASED_LABEL = (delta: number) =>
  `Archive maturity increased ${delta}%.`;

/** Demoted progress surfaces — use ArchiveProgressBar instead. */
export const DEMOTED_ARCHIVE_PROGRESS_SURFACES = [
  "ArchiveCaseFileProgress",
  "ArchiveGrowthNotes",
  "ArchiveValueBanner",
  "ArchiveOwnershipSparseLine",
  "ArchiveOwnershipPanel",
  "PatternActivationProgress",
] as const;
