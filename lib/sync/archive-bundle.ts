import { readAllCallbackReviews } from "@/lib/debug/callback-review-labels";
import { getReflectionGoal } from "@/lib/reflection-goal";
import { getAllBookmarks } from "@/lib/reflection-bookmarks";
import { isListeningModeEnabled } from "@/lib/listening-mode";
import { isFullDetailEnabled } from "@/lib/quiet-mode";
import { getReminderPreferences } from "@/lib/reminder-preferences";
import { getAllEntries } from "@/lib/storage";
import type { SyncArchiveBundle } from "@/types/sync";

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

function readDebugEvents(): unknown[] {
  if (!isBrowser() || !isDebugEventSyncAllowed()) return [];
  try {
    const raw = localStorage.getItem(DEBUG_EVENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/** Collect local archive fields for encrypted sync — plaintext stays on device until encrypted. */
export function buildLocalArchiveBundle(): SyncArchiveBundle {
  const debugEventsAllowed = isDebugEventSyncAllowed();

  return {
    version: 1,
    exportedAt: new Date().toISOString(),
    entries: getAllEntries(),
    bookmarks: getAllBookmarks(),
    settings: {
      reminders: getReminderPreferences(),
      reflectionGoal: getReflectionGoal(),
      listeningMode: isListeningModeEnabled(),
      fullDetail: isFullDetailEnabled(),
    },
    memoryReviewLabels: readAllCallbackReviews(),
    debugEventsAllowed,
    debugEvents: debugEventsAllowed ? readDebugEvents() : undefined,
  };
}

export function restoreLocalArchiveBundle(bundle: SyncArchiveBundle): void {
  if (!isBrowser()) return;

  localStorage.setItem("voicememory_entries", JSON.stringify(bundle.entries));
  localStorage.setItem("voicememory_reflection_bookmarks", JSON.stringify(bundle.bookmarks));
  localStorage.setItem(
    "voicememory_reminder_preferences",
    JSON.stringify(bundle.settings.reminders),
  );
  localStorage.setItem(
    "voicememory_reflection_goal",
    JSON.stringify(bundle.settings.reflectionGoal),
  );
  localStorage.setItem(
    "voicememory_listening_mode",
    bundle.settings.listeningMode ? "true" : "false",
  );
  localStorage.setItem(
    "voicememory_full_detail",
    bundle.settings.fullDetail ? "true" : "false",
  );
  localStorage.setItem(
    "voicememory_callback_reviews",
    JSON.stringify(bundle.memoryReviewLabels),
  );

  if (bundle.debugEventsAllowed && bundle.debugEvents) {
    localStorage.setItem(DEBUG_EVENTS_KEY, JSON.stringify(bundle.debugEvents));
  }
}
