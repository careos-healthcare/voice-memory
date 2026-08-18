import type {
  ArchiveAttachmentLevelId,
  ArchiveAttachmentReasonId,
  ArchiveMoatPerceptionId,
} from "@/types/archive-attachment";

export const ARCHIVE_ATTACHMENT_QUESTION =
  "If your archive disappeared tomorrow, how disappointed would you be?";

export const ARCHIVE_ATTACHMENT_REASON_QUESTION = "What would you miss most?";

export const ARCHIVE_MOAT_PERCEPTION_QUESTION =
  "If this archive disappeared tomorrow, could another tool recreate it?";

export const ARCHIVE_MOAT_PERCEPTION_LABELS: Record<ArchiveMoatPerceptionId, string> = {
  definitely: "Definitely",
  probably: "Probably",
  not_sure: "Not sure",
  probably_not: "Probably not",
  definitely_not: "Definitely not",
};

export const ARCHIVE_ATTACHMENT_DISMISS = "Skip";

export const ARCHIVE_ATTACHMENT_LEVEL_LABELS: Record<ArchiveAttachmentLevelId, string> = {
  not_at_all: "Not at all",
  a_little: "A little",
  moderately: "Moderately",
  very: "Very",
  extremely: "Extremely",
};

export const ARCHIVE_ATTACHMENT_REASON_LABELS: Record<ArchiveAttachmentReasonId, string> = {
  belief_history: "Belief history",
  blind_spots: "Blind spots",
  discover: "Discover",
  theory_changes: "Theory changes",
  evidence_history: "Evidence history",
  reflection_archive: "Reflection archive",
  other: "Other",
};

/** Numeric score for averaging (0–4). */
export const ARCHIVE_ATTACHMENT_LEVEL_SCORE: Record<ArchiveAttachmentLevelId, number> = {
  not_at_all: 0,
  a_little: 1,
  moderately: 2,
  very: 3,
  extremely: 4,
};

export const ARCHIVE_ATTACHMENT_STRONG_LEVELS: ArchiveAttachmentLevelId[] = ["very", "extremely"];

export const ARCHIVE_ATTACHMENT_STRONG_THRESHOLD_PERCENT = 50;
export const ARCHIVE_ATTACHMENT_WEAK_THRESHOLD_PERCENT = 20;
