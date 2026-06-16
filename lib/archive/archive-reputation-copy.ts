import type { ArchiveReputationLevel } from "@/types/archive-reputation";

export const ARCHIVE_REPUTATION_TITLE = "Archive reputation";

export const ARCHIVE_REPUTATION_CONFIDENCE_FRAMING =
  "The archive's confidence in this belief depends on the evidence available.";

export const ARCHIVE_REPUTATION_LEVEL_LABEL: Record<ArchiveReputationLevel, string> = {
  low: "Low",
  developing: "Developing",
  moderate: "Moderate",
  high: "High",
  very_high: "Very high",
};

export const ARCHIVE_REPUTATION_SUMMARY: Record<ArchiveReputationLevel, string> = {
  low: "The archive is still learning.",
  developing: "The archive has started to gather evidence.",
  moderate: "This belief appears repeatedly enough to take seriously.",
  high: "This belief has remained consistent across multiple situations.",
  very_high: "This belief has earned substantial support from your archive.",
};

export const ARCHIVE_REPUTATION_EARNED_LINE =
  "My archive has earned the right to believe this.";
