import type { ReminderPreferences } from "@/lib/reminder-preferences";
import type { ReflectionGoal } from "@/types/reflection-goal";
import type { ReflectionBookmark } from "@/types/reflection-bookmark";
import type { CallbackReviewLabel } from "@/types/callback-quality-review";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveReviewLabel {
  callbackId: string;
  labels: CallbackReviewLabel[];
  updatedAt: string;
}

export interface ArchiveSettingsSnapshot {
  reminders: ReminderPreferences;
  reflectionGoal: ReflectionGoal;
  listeningMode: boolean;
  fullDetail: boolean;
}

export interface ArchiveAudioFile {
  entryId: string;
  mimeType: string;
  dataBase64: string;
  filename: string;
}

/** Portable full archive — export, import, and restore. */
export interface VoiceMemoryArchivePackage {
  format: "voicememory-archive";
  version: 1;
  exportedAt: string;
  entries: JournalEntry[];
  bookmarks: ReflectionBookmark[];
  settings: ArchiveSettingsSnapshot;
  memoryReviewLabels: ArchiveReviewLabel[];
  audio?: ArchiveAudioFile[];
}

export interface ArchiveValidationIssue {
  level: "error" | "warning";
  message: string;
}

export interface ArchiveImportPreview {
  valid: boolean;
  formatLabel: string;
  entryCount: number;
  bookmarkCount: number;
  audioCount: number;
  reviewLabelCount: number;
  hasSettings: boolean;
  dateRange: { from: string | null; to: string | null };
  localOverlapCount: number;
  issues: ArchiveValidationIssue[];
  package: VoiceMemoryArchivePackage | null;
}

export type ArchiveRestoreMode = "replace" | "merge";

export interface ArchiveRestoreOptions {
  mode: ArchiveRestoreMode;
  includeSettings: boolean;
  includeAudio: boolean;
}
