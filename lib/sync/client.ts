import {
  applySyncContinuityModel,
  buildLocalSyncModel,
  normalizeRemoteSyncPayload,
  toEncryptedSyncPayload,
} from "@/lib/sync/sync-model";
import {
  buildEncryptedAudioBackupPlan,
  readAudioBlobForBackup,
} from "@/lib/sync/audio-backup";
import {
  fetchAccountSession,
  markSyncFinished,
  markSyncStarted,
} from "@/lib/sync/account-client";
import { getOrCreateDeviceId } from "@/lib/sync/device-id";
import {
  encryptBinaryPayload,
  encryptJsonPayload,
  decryptJsonPayload,
  ensureSyncMasterKey,
} from "@/lib/sync/encryption";
import { mergeSyncContinuityModelsWithResult } from "@/lib/sync/merge-strategy";
import {
  markPendingCarryoverAfterRemoteMerge,
} from "@/lib/sync/cross-device-continuity";
import {
  buildRestorePreview,
  clearPreRestoreSnapshot,
  inspectRemoteCoreBlob,
  restorePreRestoreSnapshot,
  snapshotPreRestoreArchive,
  writeLastRestoreAt,
  writeRecentAudioBackupFailures,
} from "@/lib/sync/sync-health";
import {
  dispatchSyncStatusChange,
  writeLastBackupAt,
  writeLastSyncError,
} from "@/lib/sync/status-storage";
import { writeLastSyncedAt } from "@/lib/sync/sync-metadata";
import type { EncryptedPayload } from "@/types/sync";
import type { SyncContinuityModel } from "@/types/sync-continuity";
import type { RestorePreview } from "@/types/sync-health";

const CORE_BLOB_ID = "archive-core";

async function pushEncryptedBlob(input: {
  id: string;
  type: "journal_snapshot" | "bookmarks" | "settings" | "memory_review_labels" | "audio_backup" | "debug_events";
  encrypted: EncryptedPayload;
}): Promise<void> {
  const response = await fetch("/api/sync/push", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      blobs: [
        {
          id: input.id,
          type: input.type,
          encrypted: input.encrypted,
          updatedAt: new Date().toISOString(),
          byteLength: input.encrypted.ciphertext.length,
        },
      ],
    }),
  });

  if (!response.ok) {
    const data = (await response.json()) as { error?: string };
    throw new Error(data.error ?? "Encrypted backup failed.");
  }
}

async function pullEncryptedCoreBlobRaw(): Promise<{
  encrypted: EncryptedPayload | null;
  model: SyncContinuityModel | null;
}> {
  const response = await fetch("/api/sync/pull", { cache: "no-store" });
  const data = (await response.json()) as {
    error?: string;
    blobs?: Array<{
      id: string;
      encrypted: EncryptedPayload;
    }>;
  };

  if (!response.ok) return { encrypted: null, model: null };

  const core = data.blobs?.find((blob) => blob.id === CORE_BLOB_ID);
  if (!core) return { encrypted: null, model: null };

  try {
    const payload = await decryptJsonPayload<unknown>(core.encrypted);
    const model = normalizeRemoteSyncPayload(payload, getOrCreateDeviceId());
    return { encrypted: core.encrypted, model };
  } catch {
    return { encrypted: core.encrypted, model: null };
  }
}

async function pullEncryptedCoreBlob(): Promise<SyncContinuityModel | null> {
  const { model } = await pullEncryptedCoreBlobRaw();
  return model;
}

/** Preview encrypted restore before applying — local archive is not modified. */
export async function previewRestoreFromEncryptedBackup(): Promise<RestorePreview> {
  const session = await fetchAccountSession();
  if (!session) throw new Error("Sign in to restore your archive.");

  await ensureSyncMasterKey();

  const { encrypted, model: remote } = await pullEncryptedCoreBlobRaw();
  if (!remote) {
    const inspection = await inspectRemoteCoreBlob(encrypted, decryptJsonPayload);
    if (inspection.corrupted) {
      throw new Error("Encrypted backup could not be read. Your local archive was not changed.");
    }
    throw new Error("No encrypted archive found for this account.");
  }

  const local = buildLocalSyncModel();
  return buildRestorePreview(local, remote);
}

/** Apply a previously previewed merge — keeps pre-restore snapshot on failure. */
export async function applyEncryptedRestoreFromPreview(
  preview: RestorePreview,
): Promise<void> {
  if (!preview.safeToApply) {
    throw new Error("Restore preview is not safe to apply.");
  }

  const { model: remote } = await pullEncryptedCoreBlobRaw();
  if (!remote) {
    throw new Error("Encrypted backup is no longer available.");
  }

  const local = buildLocalSyncModel();
  const merged = mergeSyncContinuityModelsWithResult(local, remote).model;

  snapshotPreRestoreArchive();

  try {
    await ensureSyncMasterKey();
    markPendingCarryoverAfterRemoteMerge(remote.emotionalContinuity);
    applySyncContinuityModel(merged);

    const syncedAt = new Date().toISOString();
    writeLastRestoreAt(syncedAt);
    writeLastBackupAt(syncedAt);
    writeLastSyncedAt(syncedAt);
    clearPreRestoreSnapshot();
    dispatchSyncStatusChange();
  } catch (error) {
    restorePreRestoreSnapshot();
    throw error;
  }
}

/** Encrypt, merge with remote when present, upload, and apply merged archive locally. */
export async function syncArchiveIfSignedIn(): Promise<boolean> {
  const session = await fetchAccountSession();
  if (!session) return false;

  markSyncStarted();
  writeLastSyncError(null);

  try {
    await ensureSyncMasterKey();

    const local = buildLocalSyncModel();
    const remote = await pullEncryptedCoreBlob();
    const merged = remote
      ? mergeSyncContinuityModelsWithResult(local, remote).model
      : local;

    if (remote) {
      markPendingCarryoverAfterRemoteMerge(remote.emotionalContinuity);
    }

    applySyncContinuityModel(merged);

    const payload = toEncryptedSyncPayload(merged);
    const encryptedCore = await encryptJsonPayload(payload);
    await pushEncryptedBlob({
      id: CORE_BLOB_ID,
      type: "journal_snapshot",
      encrypted: encryptedCore,
    });

    const audioPlan = buildEncryptedAudioBackupPlan();
    const audioFailures: string[] = [];
    for (const item of audioPlan.items.slice(0, 12)) {
      try {
        const blob = await readAudioBlobForBackup(item.entryId);
        if (!blob) continue;
        const encryptedAudio = await encryptBinaryPayload(await blob.arrayBuffer());
        await pushEncryptedBlob({
          id: `audio-${item.entryId}`,
          type: "audio_backup",
          encrypted: encryptedAudio,
        });
      } catch {
        audioFailures.push(item.entryId);
      }
    }
    writeRecentAudioBackupFailures(audioFailures);

    const syncedAt = new Date().toISOString();
    writeLastBackupAt(syncedAt);
    writeLastSyncedAt(syncedAt);
    dispatchSyncStatusChange();
    return true;
  } catch (error) {
    writeLastSyncError(error instanceof Error ? error.message : "Sync failed.");
    dispatchSyncStatusChange();
    return false;
  } finally {
    markSyncFinished();
  }
}

/** Pull encrypted archive, preview merge, then apply — never deletes local on failure. */
export async function restoreArchiveFromEncryptedBackup(): Promise<RestorePreview> {
  const session = await fetchAccountSession();
  if (!session) throw new Error("Sign in to restore your archive.");

  markSyncStarted();
  writeLastSyncError(null);

  try {
    await ensureSyncMasterKey();
    const preview = await previewRestoreFromEncryptedBackup();
    await applyEncryptedRestoreFromPreview(preview);
    return preview;
  } catch (error) {
    writeLastSyncError(error instanceof Error ? error.message : "Restore failed.");
    dispatchSyncStatusChange();
    throw error;
  } finally {
    markSyncFinished();
  }
}

export async function fetchSyncManifest() {
  const response = await fetch("/api/sync/manifest", { cache: "no-store" });
  if (!response.ok) return null;
  return response.json();
}

export async function inspectRemoteSyncHealth(): Promise<{
  corrupted: boolean;
  entryCount: number | null;
}> {
  const { encrypted } = await pullEncryptedCoreBlobRaw();
  const inspection = await inspectRemoteCoreBlob(encrypted, decryptJsonPayload);
  return {
    corrupted: inspection.corrupted,
    entryCount: inspection.entryCount,
  };
}
