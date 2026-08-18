import type { SyncMergeConflict } from "@/types/sync-continuity";

export interface SyncHealthIssue {
  type:
    | "corrupted_remote_blob"
    | "pending_local_changes"
    | "audio_backup_gap"
    | "missing_audio_metadata"
    | "entry_count_mismatch"
    | "pre_restore_backup_missing"
    | "sync_error"
    | "integrity_warning";
  detail: string;
  entryId?: string;
}

export interface AudioBackupHealthStatus {
  localWithAudio: number;
  pendingUpload: number;
  remoteBackedUp: number;
  recentFailures: number;
}

export interface SyncHealthReport {
  lastBackupAt: string | null;
  lastRestoreAt: string | null;
  lastSyncedAt: string | null;
  lastSyncError: string | null;
  pendingLocalChanges: boolean;
  corruptedRemoteBlob: boolean;
  localEntryCount: number;
  remoteEntryCount: number | null;
  audioBackupStatus: AudioBackupHealthStatus;
  preRestoreBackupAvailable: boolean;
  issues: SyncHealthIssue[];
}

export interface RestorePreview {
  localEntryCount: number;
  remoteEntryCount: number;
  mergedEntryCount: number;
  conflicts: SyncMergeConflict[];
  audioWarnings: string[];
  schemaUpgraded: boolean;
  safeToApply: boolean;
  summaryLines: string[];
}

export type SyncSimulationScenario =
  | "corrupted_encrypted_sync_blob"
  | "partial_restore"
  | "stale_device_conflict"
  | "offline_save_then_replay"
  | "interrupted_audio_upload"
  | "duplicate_entry_merge"
  | "missing_audio_metadata"
  | "restore_older_schema_version";

export interface SyncSimulationResult {
  scenario: SyncSimulationScenario;
  passed: boolean;
  detail: string;
  localPreserved: boolean;
  textRestored: boolean;
  audioBlocked: boolean;
}
