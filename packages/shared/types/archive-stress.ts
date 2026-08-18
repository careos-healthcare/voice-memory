export type ArchiveStressScenario =
  | "entry_save_loop_1000"
  | "interrupted_sync_mid_upload"
  | "corrupted_encrypted_payload"
  | "duplicate_device_sync_race"
  | "audio_blob_mismatch"
  | "offline_replay_after_7_days"
  | "partial_indexeddb_failure"
  | "localstorage_quota_exhaustion"
  | "restore_rollback_failure"
  | "stale_device_overwrite_attempt";

export interface StressTestResult {
  scenario: ArchiveStressScenario;
  passed: boolean;
  recoveryPath: string;
  failedAssertions: string[];
  corruptedPayloadPreview?: string;
  rollbackPreview?: string;
  detail: string;
  durationMs: number;
}

export interface StressTestRunReport {
  runAt: string;
  seed: number;
  passed: number;
  failed: number;
  allPassed: boolean;
  results: StressTestResult[];
}
