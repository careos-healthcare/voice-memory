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

export interface CrossDeviceEmotionalState {
  lastOpenedEntryId?: string;
  lastOpenedAt?: string;
  lastRevisitSource?: string;
  lastRevisitEntryId?: string;
  lastRevisitAt?: string;
  lastFollowUpPrompt?: {
    id: string;
    text: string;
    noteId?: string;
    entryId?: string;
  };
  lastFollowUpAt?: string;
  lastUnfinishedContinuation?: {
    promptId: string;
    noteId?: string;
    entryId?: string;
  };
  lastUnfinishedAt?: string;
  recentBookmarkEntryId?: string;
  recentBookmarkAt?: string;
  lastMemoryLine?: {
    noteId: string;
    noteText?: string;
    entryId?: string;
  };
  lastMemoryLineAt?: string;
  lastThenVsNow?: {
    noteId: string;
    pastEntryId?: string;
    entryId?: string;
  };
  lastThenVsNowAt?: string;
}

export interface SyncEmotionalContinuityRecord {
  state: CrossDeviceEmotionalState;
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
  emotionalContinuity: SyncEmotionalContinuityRecord | null;
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
