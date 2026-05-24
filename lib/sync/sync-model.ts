import { readAllCallbackReviews } from "@/lib/debug/callback-review-labels";
import { readLocalEvents } from "@/lib/local-analytics";
import { getReflectionGoal } from "@/lib/reflection-goal";
import { getAllBookmarks } from "@/lib/reflection-bookmarks";
import { isListeningModeEnabled } from "@/lib/listening-mode";
import { isFullDetailEnabled } from "@/lib/quiet-mode";
import { getReminderPreferences } from "@/lib/reminder-preferences";
import { getOrCreateDeviceId } from "@/lib/sync/device-id";
import { localEventKey, normalizeLegacySyncBundle } from "@/lib/sync/merge-strategy";
import { readLastSyncedAt } from "@/lib/sync/sync-metadata";
import { getAllEntries } from "@/lib/storage";
import type { SyncContinuityModel } from "@/types/sync-continuity";
import type { SyncArchiveBundle } from "@/types/sync";
import { SYNC_SCHEMA_VERSION } from "@/types/sync-continuity";

const DEBUG_EVENTS_KEY = "voicememory_local_events";
const SYNC_ALLOW_DEBUG_KEY = "voicememory_sync_allow_debug_events";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function isDebugEventSyncAllowed(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(SYNC_ALLOW_DEBUG_KEY) === "true";
}

export function setDebugEventSyncAllowed(allowed: boolean): void {
  if (!isBrowser()) return;
  if (allowed) {
    localStorage.setItem(SYNC_ALLOW_DEBUG_KEY, "true");
  } else {
    localStorage.removeItem(SYNC_ALLOW_DEBUG_KEY);
  }
}

/** Build sync-ready model from current local storage. */
export function buildLocalSyncModel(): SyncContinuityModel {
  const deviceId = getOrCreateDeviceId();
  const now = new Date().toISOString();
  const debugEventsAllowed = isDebugEventSyncAllowed();

  const entries = getAllEntries().map((entry) => ({
    entry,
    updatedAt: entry.createdAt || now,
    sourceDeviceId: deviceId,
  }));

  const bookmarks = getAllBookmarks().map((bookmark) => ({
    bookmark,
    updatedAt: bookmark.markedAt || now,
    sourceDeviceId: deviceId,
  }));

  const settings = {
    reminders: getReminderPreferences(),
    reflectionGoal: getReflectionGoal(),
    listeningMode: isListeningModeEnabled(),
    fullDetail: isFullDetailEnabled(),
    updatedAt: now,
    sourceDeviceId: deviceId,
  };

  const reviews = readAllCallbackReviews().map((review) => ({
    review,
    updatedAt: review.updatedAt || now,
    sourceDeviceId: deviceId,
  }));

  const localEvents = (debugEventsAllowed ? readLocalEvents() : []).map((event) => ({
    event,
    eventKey: localEventKey(event),
    updatedAt: event.at || now,
    sourceDeviceId: deviceId,
  }));

  const audioMetadata = entries
    .filter((row) => row.entry.audioId)
    .map((row) => ({
      entryId: row.entry.id,
      audioId: row.entry.audioId!,
      durationSeconds: row.entry.durationSeconds,
      updatedAt: row.updatedAt,
      sourceDeviceId: deviceId,
      backedUp: false,
    }));

  return {
    envelope: {
      schemaVersion: SYNC_SCHEMA_VERSION,
      deviceId,
      updatedAt: now,
      lastSyncedAt: readLastSyncedAt(),
    },
    entries,
    audioMetadata,
    bookmarks,
    settings,
    reviews,
    localEvents,
    debugEventsAllowed,
  };
}

/** Normalize encrypted payload — v2 model or legacy v1 bundle. */
export function normalizeRemoteSyncPayload(
  payload: unknown,
  fallbackDeviceId: string,
): SyncContinuityModel {
  if (
    payload &&
    typeof payload === "object" &&
    "envelope" in payload &&
    (payload as SyncContinuityModel).envelope?.schemaVersion === SYNC_SCHEMA_VERSION
  ) {
    return payload as SyncContinuityModel;
  }

  return normalizeLegacySyncBundle(payload as SyncArchiveBundle, fallbackDeviceId);
}

/** Apply sync model to local storage (full write of synced domains). */
export function applySyncContinuityModel(model: SyncContinuityModel): void {
  if (!isBrowser()) return;

  localStorage.setItem(
    "voicememory_entries",
    JSON.stringify(model.entries.map((row) => row.entry)),
  );
  localStorage.setItem(
    "voicememory_reflection_bookmarks",
    JSON.stringify(model.bookmarks.map((row) => row.bookmark)),
  );
  localStorage.setItem(
    "voicememory_reminder_preferences",
    JSON.stringify(model.settings.reminders),
  );

  if (model.settings.reflectionGoal) {
    localStorage.setItem("voicememory_reflection_goal", model.settings.reflectionGoal);
  } else {
    localStorage.removeItem("voicememory_reflection_goal");
  }

  localStorage.setItem(
    "voicememory_listening_mode",
    model.settings.listeningMode ? "true" : "false",
  );
  localStorage.setItem(
    "voicememory_full_detail",
    model.settings.fullDetail ? "true" : "false",
  );
  localStorage.setItem(
    "voicememory_callback_reviews",
    JSON.stringify(model.reviews.map((row) => row.review)),
  );

  if (model.debugEventsAllowed) {
    localStorage.setItem(
      DEBUG_EVENTS_KEY,
      JSON.stringify(model.localEvents.map((row) => row.event)),
    );
    localStorage.setItem(SYNC_ALLOW_DEBUG_KEY, "true");
  }
}

/** Legacy plaintext bundle for backward-compatible export paths. */
export function buildLocalArchiveBundle(): SyncArchiveBundle {
  const model = buildLocalSyncModel();

  return {
    version: 1,
    exportedAt: model.envelope.updatedAt,
    entries: model.entries.map((row) => row.entry),
    bookmarks: model.bookmarks.map((row) => row.bookmark),
    settings: {
      reminders: model.settings.reminders,
      reflectionGoal: model.settings.reflectionGoal,
      listeningMode: model.settings.listeningMode,
      fullDetail: model.settings.fullDetail,
    },
    memoryReviewLabels: model.reviews.map((row) => row.review),
    debugEventsAllowed: model.debugEventsAllowed,
    debugEvents: model.debugEventsAllowed
      ? model.localEvents.map((row) => row.event)
      : undefined,
  };
}

export function restoreLocalArchiveBundle(bundle: SyncArchiveBundle): void {
  const model = normalizeLegacySyncBundle(bundle, getOrCreateDeviceId());
  applySyncContinuityModel(model);
}

export function toEncryptedSyncPayload(model: SyncContinuityModel): SyncContinuityModel {
  return model;
}
