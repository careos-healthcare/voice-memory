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
  | "debug_events"
  | "crdt_operations";

export interface SyncBlobRecord {
  id: string;
  type: SyncBlobType;
  encrypted: EncryptedPayload;
  updatedAt: string;
  byteLength: number;
  deviceId?: string;
  vectorClock?: Record<string, number>;
  keyEpoch?: number;
}

export interface SyncManifest {
  userId: string;
  version: number;
  updatedAt: string;
  blobs: Array<{
    id: string;
    type: SyncBlobType;
    updatedAt: string;
    byteLength: number;
  }>;
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
