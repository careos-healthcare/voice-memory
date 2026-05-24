import type { JournalEntry, Reflection } from "@/types/journal";

export type IntegrityIssueType =
  | "missing_audio_reference"
  | "duplicate_id"
  | "malformed_reflection"
  | "missing_timestamp"
  | "missing_transcript"
  | "invalid_entry_shape";

export interface IntegrityIssue {
  type: IntegrityIssueType;
  entryId?: string;
  detail: string;
}

export interface StorageHealthReport {
  storageVersion: number;
  entriesCount: number;
  audioCount: number;
  brokenAudioReferences: number;
  duplicateIds: number;
  malformedReflections: number;
  missingTimestamps: number;
  issues: IntegrityIssue[];
}

export interface RecoveryDraft {
  version: 1;
  id: string;
  transcript: string;
  durationSeconds: number;
  createdAt: string;
  reflectionPending: boolean;
  reflection?: Reflection | null;
  audioId?: string;
  reason: "analysis_failed" | "save_failed" | "unexpected_stop";
}

export interface RepairResult {
  repaired: number;
  details: string[];
}

export type SaveAudioResult =
  | { saved: true; entryId: string }
  | { saved: false; entryId: string };
