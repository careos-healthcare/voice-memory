import { listAudioEntryIds } from "@/lib/audio-storage";
import {
  crossCheckAudioMetadata,
  isCorruptedEncryptedPayload,
  validateSyncContinuityModel,
} from "@/lib/reliability/archive-integrity";
import { getOrCreateDeviceId } from "@/lib/sync/device-id";
import { buildEncryptedAudioBackupPlan } from "@/lib/sync/audio-backup";
import {
  mergeSyncContinuityModelsWithResult,
  normalizeLegacySyncBundle,
} from "@/lib/sync/merge-strategy";
import {
  buildLocalSyncModel,
  normalizeRemoteSyncPayload,
} from "@/lib/sync/sync-model";
import { readLastBackupAt, readLastSyncError } from "@/lib/sync/status-storage";
import { readLastSyncedAt } from "@/lib/sync/sync-metadata";
import { getAllEntries } from "@/lib/storage";
import type { EncryptedPayload } from "@/types/sync";
import type { SyncContinuityModel } from "@/types/sync-continuity";
import type {
  RestorePreview,
  SyncHealthIssue,
  SyncHealthReport,
} from "@/types/sync-health";

const PRE_RESTORE_SNAPSHOT_KEY = "voicememory_pre_restore_snapshot";
const LAST_RESTORE_KEY = "voicememory_sync_last_restore_at";
const AUDIO_FAILURE_KEY = "voicememory_sync_audio_failures";

const SNAPSHOT_KEYS = [
  "voicememory_entries",
  "voicememory_reflection_bookmarks",
  "voicememory_reminder_preferences",
  "voicememory_reflection_goal",
  "voicememory_listening_mode",
  "voicememory_full_detail",
  "voicememory_callback_reviews",
  "voicememory_emotional_continuity",
  "voicememory_local_events",
] as const;

interface PreRestoreSnapshot {
  savedAt: string;
  keys: Record<string, string | null>;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Calm user-facing copy when sync or backup fails. */
export const SYNC_FAILURE_COPY = {
  localArchiveSafe: "Your local archive is safe.",
  backupPaused: "Backup paused. Nothing was deleted.",
} as const;

export function readLastRestoreAt(): string | null {
  if (!isBrowser()) return null;
  return localStorage.getItem(LAST_RESTORE_KEY);
}

export function writeLastRestoreAt(iso: string): void {
  if (!isBrowser()) return;
  localStorage.setItem(LAST_RESTORE_KEY, iso);
}

export function hasPreRestoreBackup(): boolean {
  if (!isBrowser()) return false;
  return Boolean(localStorage.getItem(PRE_RESTORE_SNAPSHOT_KEY));
}

/** Snapshot all archive domains before restore — never overwrite an existing snapshot. */
export function snapshotPreRestoreArchive(): void {
  if (!isBrowser()) return;
  if (localStorage.getItem(PRE_RESTORE_SNAPSHOT_KEY)) return;

  const keys: Record<string, string | null> = {};
  for (const key of SNAPSHOT_KEYS) {
    keys[key] = localStorage.getItem(key);
  }

  const snapshot: PreRestoreSnapshot = {
    savedAt: new Date().toISOString(),
    keys,
  };
  localStorage.setItem(PRE_RESTORE_SNAPSHOT_KEY, JSON.stringify(snapshot));
}

export function restorePreRestoreSnapshot(): boolean {
  if (!isBrowser()) return false;

  const raw = localStorage.getItem(PRE_RESTORE_SNAPSHOT_KEY);
  if (!raw) return false;

  try {
    const snapshot = JSON.parse(raw) as PreRestoreSnapshot;
    for (const [key, value] of Object.entries(snapshot.keys)) {
      if (value === null) {
        localStorage.removeItem(key);
      } else {
        localStorage.setItem(key, value);
      }
    }
    return true;
  } catch {
    return false;
  }
}

export function clearPreRestoreSnapshot(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(PRE_RESTORE_SNAPSHOT_KEY);
}

export function readRecentAudioBackupFailures(): string[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(AUDIO_FAILURE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as string[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function writeRecentAudioBackupFailures(entryIds: string[]): void {
  if (!isBrowser()) return;
  if (entryIds.length === 0) {
    localStorage.removeItem(AUDIO_FAILURE_KEY);
    return;
  }
  localStorage.setItem(AUDIO_FAILURE_KEY, JSON.stringify(entryIds.slice(0, 24)));
}

export function detectPendingLocalChanges(): boolean {
  const local = buildLocalSyncModel();
  const lastSynced = readLastSyncedAt();
  if (!lastSynced) return local.entries.length > 0;

  const localUpdated = new Date(local.envelope.updatedAt).getTime();
  const syncedAt = new Date(lastSynced).getTime();
  return Number.isFinite(localUpdated) && localUpdated > syncedAt + 1000;
}

export function buildRestorePreview(
  local: SyncContinuityModel,
  remote: SyncContinuityModel,
): RestorePreview {
  const mergeResult = mergeSyncContinuityModelsWithResult(local, remote);
  const validation = validateSyncContinuityModel(mergeResult.model);
  const audioWarnings = validation.issues
    .filter((issue) => issue.type === "missing_audio_metadata" || issue.type === "orphan_audio_metadata")
    .map((issue) => issue.detail);

  const schemaUpgraded = remote.envelope.schemaVersion < local.envelope.schemaVersion;
  const summaryLines: string[] = [
    `${local.entries.length} entries on this device`,
    `${remote.entries.length} entries in backup`,
    `${mergeResult.model.entries.length} entries after merge`,
  ];

  if (mergeResult.conflicts.length > 0) {
    summaryLines.push(`${mergeResult.conflicts.length} overlapping updates resolved`);
  }
  if (audioWarnings.length > 0) {
    summaryLines.push("Some recordings may need to sync separately.");
  }

  return {
    localEntryCount: local.entries.length,
    remoteEntryCount: remote.entries.length,
    mergedEntryCount: mergeResult.model.entries.length,
    conflicts: mergeResult.conflicts,
    audioWarnings,
    schemaUpgraded,
    safeToApply: validation.valid || mergeResult.model.entries.length > 0,
    summaryLines,
  };
}

export async function buildSyncHealthReport(): Promise<SyncHealthReport> {
  const issues: SyncHealthIssue[] = [];
  const lastBackupAt = readLastBackupAt();
  const lastRestoreAt = readLastRestoreAt();
  const lastSyncedAt = readLastSyncedAt();
  const lastSyncError = readLastSyncError();
  const localEntryCount = getAllEntries().length;
  const pendingLocalChanges = detectPendingLocalChanges();
  const preRestoreBackupAvailable = hasPreRestoreBackup();
  const audioPlan = buildEncryptedAudioBackupPlan();
  const recentFailures = readRecentAudioBackupFailures();

  let remoteEntryCount: number | null = null;
  let corruptedRemoteBlob = false;
  let remoteBackedUp = 0;

  if (lastSyncError) {
    issues.push({
      type: "sync_error",
      detail: lastSyncError,
    });
  }

  if (pendingLocalChanges) {
    issues.push({
      type: "pending_local_changes",
      detail: "Local archive has changes not yet backed up.",
    });
  }

  if (!preRestoreBackupAvailable && lastRestoreAt) {
    issues.push({
      type: "pre_restore_backup_missing",
      detail: "No pre-restore snapshot on disk (may have been cleared after success).",
    });
  }

  try {
    const response = await fetch("/api/sync/manifest", { cache: "no-store" });
    if (response.ok) {
      const manifest = (await response.json()) as {
        blobs?: Array<{ id: string; type: string }>;
      };
      remoteBackedUp =
        manifest.blobs?.filter((blob) => blob.type === "audio_backup").length ?? 0;
    }
  } catch {
    // Manifest unavailable offline — not an integrity failure.
  }

  const audioBackupStatus = {
    localWithAudio: audioPlan.items.length,
    pendingUpload: audioPlan.items.filter((item) => item.status === "pending").length,
    remoteBackedUp,
    recentFailures: recentFailures.length,
  };

  if (audioPlan.items.length > remoteBackedUp && remoteBackedUp > 0) {
    issues.push({
      type: "audio_backup_gap",
      detail: `${audioPlan.items.length - remoteBackedUp} recording(s) may not be backed up yet.`,
    });
  }

  if (recentFailures.length > 0) {
    issues.push({
      type: "audio_backup_gap",
      detail: `${recentFailures.length} recent audio backup attempt(s) did not finish.`,
    });
  }

  return {
    lastBackupAt,
    lastRestoreAt,
    lastSyncedAt,
    lastSyncError,
    pendingLocalChanges,
    corruptedRemoteBlob,
    localEntryCount,
    remoteEntryCount,
    audioBackupStatus,
    preRestoreBackupAvailable,
    issues,
  };
}

export async function inspectRemoteCoreBlob(
  encrypted: EncryptedPayload | null | undefined,
  decrypt: (payload: EncryptedPayload) => Promise<unknown>,
): Promise<{
  corrupted: boolean;
  entryCount: number | null;
  issues: SyncHealthIssue[];
}> {
  const issues: SyncHealthIssue[] = [];

  if (isCorruptedEncryptedPayload(encrypted)) {
    return {
      corrupted: true,
      entryCount: null,
      issues: [{ type: "corrupted_remote_blob", detail: "Remote archive blob is unreadable." }],
    };
  }

  try {
    const payload = await decrypt(encrypted!);
    const model = normalizeRemoteSyncPayload(payload, getOrCreateDeviceId());
    const validation = validateSyncContinuityModel(model);

    for (const issue of validation.issues) {
      issues.push({
        type: "integrity_warning",
        detail: issue.detail,
        entryId: issue.entryId,
      });
    }

    const audioIds = new Set(await listAudioEntryIds());
    for (const issue of crossCheckAudioMetadata(model, audioIds)) {
      issues.push({
        type: "missing_audio_metadata",
        detail: issue.detail,
        entryId: issue.entryId,
      });
    }

    return {
      corrupted: false,
      entryCount: model.entries.length,
      issues,
    };
  } catch {
    return {
      corrupted: true,
      entryCount: null,
      issues: [{ type: "corrupted_remote_blob", detail: "Could not decrypt remote archive blob." }],
    };
  }
}

export function getCalmSyncErrorLines(): string[] {
  return [SYNC_FAILURE_COPY.localArchiveSafe, SYNC_FAILURE_COPY.backupPaused];
}

export function normalizeLegacyPayloadForPreview(
  payload: unknown,
  deviceId: string,
): SyncContinuityModel {
  if (
    payload &&
    typeof payload === "object" &&
    "envelope" in payload
  ) {
    return normalizeRemoteSyncPayload(payload, deviceId);
  }
  return normalizeLegacySyncBundle(payload as Parameters<typeof normalizeLegacySyncBundle>[0], deviceId);
}
