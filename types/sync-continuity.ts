import type { StoredCallbackReview } from "@/lib/debug/callback-review-labels";
import type { LocalAnalyticsEvent } from "@/lib/local-analytics";
import type { JournalEntry } from "@/types/journal";
import type { ReflectionBookmark } from "@/types/reflection-bookmark";
import type { ReflectionGoal } from "@/types/reflection-goal";

/** Current sync-ready schema — bump when merge semantics change. */
export const SYNC_SCHEMA_VERSION = 2;

export interface SyncEnvelope {
  schemaVersion: typeof SYNC_SCHEMA_VERSION;
  deviceId: string;
  updatedAt: string;
  lastSyncedAt: string | null;
}

export interface SyncEntryRecord {
  entry: JournalEntry;
  updatedAt: string;
  sourceDeviceId: string;
}

export interface SyncAudioMetadataRecord {
  entryId: string;
  audioId: string;
  durationSeconds: number;
  mimeType?: string;
  byteLength?: number;
  updatedAt: string;
  sourceDeviceId: string;
  backedUp: boolean;
}

export interface SyncBookmarkRecord {
  bookmark: ReflectionBookmark;
  updatedAt: string;
  sourceDeviceId: string;
}

export interface SyncSettingsSnapshot {
  reminders: ReminderPreferences;
  reflectionGoal: ReflectionGoal;
  listeningMode: boolean;
  fullDetail: boolean;
}

/** Inline mirror of reminder prefs to keep types free of runtime imports. */
export interface ReminderPreferences {
  dailyReflection: boolean;
  afterStressfulEntry: boolean;
  weeklyReview: boolean;
  inactiveThreeDays: boolean;
  preferredReflectionHour: number;
}

export interface SyncSettingsRecord extends SyncSettingsSnapshot {
  updatedAt: string;
  sourceDeviceId: string;
}

export interface SyncReviewRecord {
  review: StoredCallbackReview;
  updatedAt: string;
  sourceDeviceId: string;
}

export interface SyncLocalEventRecord {
  event: LocalAnalyticsEvent;
  eventKey: string;
  updatedAt: string;
  sourceDeviceId: string;
}

/** Sync-ready archive payload — encrypted as archive-core. */
export interface SyncContinuityModel {
  envelope: SyncEnvelope;
  entries: SyncEntryRecord[];
  audioMetadata: SyncAudioMetadataRecord[];
  bookmarks: SyncBookmarkRecord[];
  settings: SyncSettingsRecord;
  reviews: SyncReviewRecord[];
  localEvents: SyncLocalEventRecord[];
  debugEventsAllowed: boolean;
}

export interface SyncMergeResult {
  model: SyncContinuityModel;
  conflicts: SyncMergeConflict[];
}

export interface SyncMergeConflict {
  domain: "entry" | "bookmark" | "review" | "settings" | "event";
  key: string;
  resolution: "kept_local" | "kept_remote" | "merged";
}
