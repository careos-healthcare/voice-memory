import type { SyncContinuityModel } from "@/types/sync-continuity";

/** Encrypted payload envelope — server never sees plaintext. */
export interface EncryptedPayload {
  ciphertext: string;
  iv: string;
  version: 1;
}

export type SyncBlobType =
  | "journal_snapshot"
  | "bookmarks"
  | "settings"
  | "memory_review_labels"
  | "audio_backup"
  | "debug_events";

export interface SyncBlobRecord {
  id: string;
  type: SyncBlobType;
  encrypted: EncryptedPayload;
  updatedAt: string;
  byteLength: number;
}

export interface SyncManifest {
  userId: string;
  version: number;
  updatedAt: string;
  /** Monotonic change-log head — clients store this as the incremental pull cursor. */
  latestSequence: number;
  blobs: Array<{
    id: string;
    type: SyncBlobType;
    updatedAt: string;
    byteLength: number;
  }>;
}

export type SyncChangeKind = "upsert" | "delete";

export interface SyncChangeRecord {
  sequence: number;
  blobType: SyncBlobType;
  blobId: string;
  changeKind: SyncChangeKind;
  updatedAt: string;
  tombstone: boolean;
}

export interface SyncChangesResponse {
  latestSequence: number;
  changes: SyncChangeRecord[];
  blobs: SyncBlobRecord[];
}

/** Per-blob outcome for idempotent `POST /api/sync/push`. */
export type SyncBlobUpsertStatus = "created" | "updated" | "existing";

export interface SyncBlobStatusMatrixEntry {
  id: string;
  type: SyncBlobType;
  status: SyncBlobUpsertStatus;
}

export interface SyncPushUpsertReport {
  manifest: SyncManifest;
  statusMatrix: SyncBlobStatusMatrixEntry[];
}

/** Legacy v1 bundle — upgraded to SyncContinuityModel on read. */
export interface SyncArchiveBundle {
  version: 1;
  exportedAt: string;
  entries: unknown[];
  bookmarks: unknown[];
  settings: {
    reminders: unknown;
    reflectionGoal: unknown;
    listeningMode: boolean;
    fullDetail: boolean;
  };
  memoryReviewLabels: unknown[];
  debugEventsAllowed: boolean;
  debugEvents?: unknown[];
}

/** Encrypted archive-core payload — prefer SyncContinuityModel (schema v2). */
export type SyncEncryptedPayload = SyncContinuityModel | SyncArchiveBundle;

export interface AudioBackupPlanItem {
  entryId: string;
  audioId: string;
  durationSeconds: number;
  status: "pending" | "queued" | "backed_up";
}

export interface AudioBackupPlan {
  items: AudioBackupPlanItem[];
  note: string;
}
