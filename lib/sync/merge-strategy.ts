import type { LocalAnalyticsEvent } from "@/lib/local-analytics";
import type { JournalEntry } from "@/types/journal";
import type { ReflectionBookmark } from "@/types/reflection-bookmark";
import type {
  SyncAudioMetadataRecord,
  SyncBookmarkRecord,
  SyncContinuityModel,
  SyncEntryRecord,
  SyncEnvelope,
  SyncLocalEventRecord,
  SyncMergeConflict,
  SyncMergeResult,
  SyncPhotoMetadataRecord,
  SyncReviewRecord,
  SyncSettingsRecord,
} from "@/types/sync-continuity";
import { SYNC_SCHEMA_VERSION } from "@/types/sync-continuity";
import { mergeEmotionalContinuityRecords } from "@/lib/sync/cross-device-continuity";
import type { SyncArchiveBundle } from "@/types/sync";

function parseTime(iso: string | undefined): number {
  if (!iso) return 0;
  const time = new Date(iso).getTime();
  return Number.isFinite(time) ? time : 0;
}

export function isNewer(left: string, right: string): boolean {
  return parseTime(left) > parseTime(right);
}

export function isSameDevice(
  leftDeviceId: string,
  rightDeviceId: string,
  localDeviceId: string,
): "local" | "remote" | "other" {
  if (leftDeviceId === localDeviceId) return "local";
  if (rightDeviceId === localDeviceId) return "remote";
  return "other";
}

/** Prefer local on timestamp tie — preserves device data on conflict. */
export function pickNewerRecord<T extends { updatedAt: string; sourceDeviceId: string }>(
  local: T,
  remote: T,
  localDeviceId: string,
): { winner: T; resolution: "kept_local" | "kept_remote" } {
  if (isNewer(local.updatedAt, remote.updatedAt)) {
    return { winner: local, resolution: "kept_local" };
  }
  if (isNewer(remote.updatedAt, local.updatedAt)) {
    return { winner: remote, resolution: "kept_remote" };
  }

  if (local.sourceDeviceId === localDeviceId) {
    return { winner: local, resolution: "kept_local" };
  }
  if (remote.sourceDeviceId === localDeviceId) {
    return { winner: remote, resolution: "kept_local" };
  }

  return { winner: local, resolution: "kept_local" };
}

export function mergeEntryRecords(
  local: SyncEntryRecord[],
  remote: SyncEntryRecord[],
  localDeviceId: string,
): { merged: SyncEntryRecord[]; conflicts: Array<{ key: string; resolution: "kept_local" | "kept_remote" }> } {
  const byId = new Map<string, SyncEntryRecord>();
  const conflicts: Array<{ key: string; resolution: "kept_local" | "kept_remote" }> = [];

  for (const record of [...remote, ...local]) {
    const existing = byId.get(record.entry.id);
    if (!existing) {
      byId.set(record.entry.id, record);
      continue;
    }

    const { winner, resolution } = pickNewerRecord(existing, record, localDeviceId);
    byId.set(record.entry.id, winner);
    if (existing.entry.id === record.entry.id && existing.updatedAt !== record.updatedAt) {
      conflicts.push({ key: record.entry.id, resolution });
    }
  }

  const merged = Array.from(byId.values()).sort(
    (a, b) => parseTime(b.entry.createdAt) - parseTime(a.entry.createdAt),
  );

  return { merged, conflicts };
}

export function mergeAudioMetadata(
  local: SyncAudioMetadataRecord[],
  remote: SyncAudioMetadataRecord[],
  localDeviceId: string,
): SyncAudioMetadataRecord[] {
  const byEntryId = new Map<string, SyncAudioMetadataRecord>();

  for (const record of [...remote, ...local]) {
    const existing = byEntryId.get(record.entryId);
    if (!existing) {
      byEntryId.set(record.entryId, record);
      continue;
    }
    const { winner } = pickNewerRecord(existing, record, localDeviceId);
    byEntryId.set(record.entryId, winner);
  }

  return Array.from(byEntryId.values());
}

export function mergePhotoMetadata(
  local: SyncPhotoMetadataRecord[],
  remote: SyncPhotoMetadataRecord[],
  localDeviceId: string,
): SyncPhotoMetadataRecord[] {
  const byEntryId = new Map<string, SyncPhotoMetadataRecord>();

  for (const record of [...remote, ...local]) {
    const existing = byEntryId.get(record.entryId);
    if (!existing) {
      byEntryId.set(record.entryId, record);
      continue;
    }
    const { winner } = pickNewerRecord(existing, record, localDeviceId);
    byEntryId.set(record.entryId, winner);
  }

  return Array.from(byEntryId.values());
}

export function mergeBookmarkRecords(
  local: SyncBookmarkRecord[],
  remote: SyncBookmarkRecord[],
  localDeviceId: string,
): SyncBookmarkRecord[] {
  const byEntryId = new Map<string, SyncBookmarkRecord>();

  for (const record of [...remote, ...local]) {
    const existing = byEntryId.get(record.bookmark.entryId);
    if (!existing) {
      byEntryId.set(record.bookmark.entryId, record);
      continue;
    }
    const { winner } = pickNewerRecord(existing, record, localDeviceId);
    byEntryId.set(record.bookmark.entryId, winner);
  }

  return Array.from(byEntryId.values());
}

export function mergeReviewRecords(
  local: SyncReviewRecord[],
  remote: SyncReviewRecord[],
  localDeviceId: string,
): SyncReviewRecord[] {
  const byCallbackId = new Map<string, SyncReviewRecord>();

  for (const record of [...remote, ...local]) {
    const existing = byCallbackId.get(record.review.callbackId);
    if (!existing) {
      byCallbackId.set(record.review.callbackId, record);
      continue;
    }
    const { winner } = pickNewerRecord(existing, record, localDeviceId);
    byCallbackId.set(record.review.callbackId, winner);
  }

  return Array.from(byCallbackId.values());
}

export function mergeSettingsRecords(
  local: SyncSettingsRecord,
  remote: SyncSettingsRecord,
  localDeviceId: string,
): SyncSettingsRecord {
  const { winner } = pickNewerRecord(local, remote, localDeviceId);
  return winner;
}

export function localEventKey(event: LocalAnalyticsEvent): string {
  return `${event.name}:${event.at}:${JSON.stringify(event.meta ?? {})}`;
}

export function mergeLocalEventRecords(
  local: SyncLocalEventRecord[],
  remote: SyncLocalEventRecord[],
): SyncLocalEventRecord[] {
  const byKey = new Map<string, SyncLocalEventRecord>();

  for (const record of [...remote, ...local]) {
    if (!byKey.has(record.eventKey)) {
      byKey.set(record.eventKey, record);
    }
  }

  return Array.from(byKey.values())
    .sort((a, b) => parseTime(a.event.at) - parseTime(b.event.at))
    .slice(-500);
}

export function mergeSyncContinuityModelsWithResult(
  local: SyncContinuityModel,
  remote: SyncContinuityModel,
): SyncMergeResult {
  const localDeviceId = local.envelope.deviceId;
  const now = new Date().toISOString();

  const entries = mergeEntryRecords(local.entries, remote.entries, localDeviceId);
  const audioMetadata = mergeAudioMetadata(
    local.audioMetadata,
    remote.audioMetadata,
    localDeviceId,
  );
  const photoMetadata = mergePhotoMetadata(
    local.photoMetadata ?? [],
    remote.photoMetadata ?? [],
    localDeviceId,
  );
  const bookmarks = mergeBookmarkRecords(local.bookmarks, remote.bookmarks, localDeviceId);
  const reviews = mergeReviewRecords(local.reviews, remote.reviews, localDeviceId);
  const settings = mergeSettingsRecords(local.settings, remote.settings, localDeviceId);
  const localEvents = mergeLocalEventRecords(local.localEvents, remote.localEvents);
  const emotionalContinuity = mergeEmotionalContinuityRecords(
    local.emotionalContinuity,
    remote.emotionalContinuity,
    localDeviceId,
  );

  const envelope: SyncEnvelope = {
    schemaVersion: SYNC_SCHEMA_VERSION,
    deviceId: localDeviceId,
    updatedAt: now,
    lastSyncedAt: now,
  };

  const conflicts: SyncMergeConflict[] = entries.conflicts.map((row) => ({
    domain: "entry" as const,
    key: row.key,
    resolution: row.resolution,
  }));

  return {
    model: {
      envelope,
      entries: entries.merged,
      audioMetadata,
      photoMetadata,
      bookmarks,
      settings,
      reviews,
      localEvents,
      emotionalContinuity,
      debugEventsAllowed: local.debugEventsAllowed || remote.debugEventsAllowed,
    },
    conflicts,
  };
}

export function mergeSyncContinuityModels(
  local: SyncContinuityModel,
  remote: SyncContinuityModel,
): SyncContinuityModel {
  return mergeSyncContinuityModelsWithResult(local, remote).model;
}

/** Upgrade legacy v1 bundle shape to sync continuity model. */
export function normalizeLegacySyncBundle(
  bundle: SyncArchiveBundle,
  deviceId: string,
): SyncContinuityModel {
  const now = new Date().toISOString();
  const entries = (bundle.entries as JournalEntry[]).map((entry) => ({
    entry,
    updatedAt: entry.createdAt || now,
    sourceDeviceId: deviceId,
  }));

  const bookmarks = (bundle.bookmarks as ReflectionBookmark[]).map((bookmark) => ({
    bookmark,
    updatedAt: bookmark.markedAt || now,
    sourceDeviceId: deviceId,
  }));

  const rawSettings = bundle.settings;

  return {
    envelope: {
      schemaVersion: SYNC_SCHEMA_VERSION,
      deviceId,
      updatedAt: bundle.exportedAt || now,
      lastSyncedAt: null,
    },
    entries,
    audioMetadata: entries
      .filter((row) => row.entry.audioId)
      .map((row) => ({
        entryId: row.entry.id,
        audioId: row.entry.audioId!,
        durationSeconds: row.entry.durationSeconds,
        updatedAt: row.updatedAt,
        sourceDeviceId: deviceId,
        backedUp: false,
      })),
    photoMetadata: entries
      .filter((row) => row.entry.photo?.photoId)
      .map((row) => ({
        entryId: row.entry.id,
        photoId: row.entry.photo!.photoId,
        mimeType: row.entry.photo!.mimeType,
        byteLength: row.entry.photo!.byteLength,
        contentHash: row.entry.photo!.contentHash,
        width: row.entry.photo!.width,
        height: row.entry.photo!.height,
        attachedAt: row.entry.photo!.attachedAt,
        updatedAt: row.entry.photo!.attachedAt || row.updatedAt,
        sourceDeviceId: deviceId,
        backedUp: false,
      })),
    bookmarks,
    settings: {
      reminders: rawSettings.reminders as SyncSettingsRecord["reminders"],
      reflectionGoal: rawSettings.reflectionGoal as SyncSettingsRecord["reflectionGoal"],
      listeningMode: Boolean(rawSettings.listeningMode),
      fullDetail: Boolean(rawSettings.fullDetail),
      updatedAt: bundle.exportedAt || now,
      sourceDeviceId: deviceId,
    },
    reviews: (bundle.memoryReviewLabels as SyncReviewRecord["review"][]).map((review) => ({
      review,
      updatedAt: review.updatedAt || now,
      sourceDeviceId: deviceId,
    })),
    localEvents: (bundle.debugEvents ?? []).map((event) => {
      const typed = event as LocalAnalyticsEvent;
      return {
        event: typed,
        eventKey: localEventKey(typed),
        updatedAt: typed.at || now,
        sourceDeviceId: deviceId,
      };
    }),
    emotionalContinuity: null,
    debugEventsAllowed: bundle.debugEventsAllowed,
  };
}

export function isSyncContinuityModel(value: unknown): value is SyncContinuityModel {
  if (!value || typeof value !== "object") return false;
  const record = value as SyncContinuityModel;
  return (
    record.envelope?.schemaVersion === SYNC_SCHEMA_VERSION &&
    Array.isArray(record.entries) &&
    Array.isArray(record.bookmarks)
  );
}
