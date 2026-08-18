export const ARCHIVE_ATTACHMENT_LEVEL_IDS = [
  "not_at_all",
  "a_little",
  "moderately",
  "very",
  "extremely",
] as const;

export type ArchiveAttachmentLevelId = (typeof ARCHIVE_ATTACHMENT_LEVEL_IDS)[number];

export const ARCHIVE_ATTACHMENT_REASON_IDS = [
  "belief_history",
  "blind_spots",
  "discover",
  "theory_changes",
  "evidence_history",
  "reflection_archive",
  "other",
] as const;

export type ArchiveAttachmentReasonId = (typeof ARCHIVE_ATTACHMENT_REASON_IDS)[number];

export const ARCHIVE_MOAT_PERCEPTION_IDS = [
  "definitely",
  "probably",
  "not_sure",
  "probably_not",
  "definitely_not",
] as const;

export type ArchiveMoatPerceptionId = (typeof ARCHIVE_MOAT_PERCEPTION_IDS)[number];

export type ArchiveAttachmentVerdict = "strong" | "weak" | "mixed" | "insufficient_data";

export interface ArchiveAttachmentRecord {
  id: string;
  level: ArchiveAttachmentLevelId;
  score: number;
  answeredAt: string;
  reflectionCount: number;
  archiveAgeDays: number;
  reason?: ArchiveAttachmentReasonId;
  reasonAnsweredAt?: string;
  /** Archive Loss Test — could another tool recreate this archive? */
  archiveMoatPerception?: ArchiveMoatPerceptionId;
  moatPerceptionAnsweredAt?: string;
}

export interface ArchiveAttachmentDistributionRow {
  level: ArchiveAttachmentLevelId;
  label: string;
  count: number;
  sharePercent: number;
}

export interface ArchiveAttachmentOutcomeRow {
  level: ArchiveAttachmentLevelId;
  label: string;
  count: number;
  returnRate: number | null;
  subscriptionRate: number | null;
  breakthroughRate: number | null;
}

export interface ArchiveAttachmentReasonRow {
  reason: ArchiveAttachmentReasonId;
  label: string;
  count: number;
  sharePercent: number;
}

export interface ArchiveAttachmentReport {
  criticalQuestion: string;
  criticalAnswer: string;
  verdict: ArchiveAttachmentVerdict;
  strongAttachmentPercent: number | null;
  weakAttachmentPercent: number | null;
  averageAttachmentScore: number | null;
  totalResponses: number;
  distribution: ArchiveAttachmentDistributionRow[];
  byLevelOutcomes: ArchiveAttachmentOutcomeRow[];
  topAttachmentReasons: ArchiveAttachmentReasonRow[];
  archiveAgeSummary: string;
  recentRecords: ArchiveAttachmentRecord[];
}
