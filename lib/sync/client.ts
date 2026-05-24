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
import { mergeSyncContinuityModels } from "@/lib/sync/merge-strategy";
import {
  markPendingCarryoverAfterRemoteMerge,
} from "@/lib/sync/cross-device-continuity";
import {
  dispatchSyncStatusChange,
  writeLastBackupAt,
  writeLastSyncError,
} from "@/lib/sync/status-storage";
import { writeLastSyncedAt } from "@/lib/sync/sync-metadata";
import type { EncryptedPayload } from "@/types/sync";
import type { SyncContinuityModel } from "@/types/sync-continuity";

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

async function pullEncryptedCoreBlob(): Promise<SyncContinuityModel | null> {
  const response = await fetch("/api/sync/pull", { cache: "no-store" });
  const data = (await response.json()) as {
    error?: string;
    blobs?: Array<{
      id: string;
      encrypted: EncryptedPayload;
    }>;
  };

  if (!response.ok) return null;

  const core = data.blobs?.find((blob) => blob.id === CORE_BLOB_ID);
  if (!core) return null;

  const payload = await decryptJsonPayload<unknown>(core.encrypted);
  return normalizeRemoteSyncPayload(payload, getOrCreateDeviceId());
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
    const merged = remote ? mergeSyncContinuityModels(local, remote) : local;
    const payload = toEncryptedSyncPayload(merged);

    if (remote) {
      markPendingCarryoverAfterRemoteMerge(remote.emotionalContinuity);
    }

    applySyncContinuityModel(merged);

    const encryptedCore = await encryptJsonPayload(payload);
    await pushEncryptedBlob({
      id: CORE_BLOB_ID,
      type: "journal_snapshot",
      encrypted: encryptedCore,
    });

    const audioPlan = buildEncryptedAudioBackupPlan();
    for (const item of audioPlan.items.slice(0, 12)) {
      const blob = await readAudioBlobForBackup(item.entryId);
      if (!blob) continue;
      const encryptedAudio = await encryptBinaryPayload(await blob.arrayBuffer());
      await pushEncryptedBlob({
        id: `audio-${item.entryId}`,
        type: "audio_backup",
        encrypted: encryptedAudio,
      });
    }

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

/** Pull encrypted archive and merge into local storage (preserves local on conflict). */
export async function restoreArchiveFromEncryptedBackup(): Promise<void> {
  const session = await fetchAccountSession();
  if (!session) throw new Error("Sign in to restore your archive.");

  markSyncStarted();
  writeLastSyncError(null);

  try {
    const remote = await pullEncryptedCoreBlob();
    if (!remote) throw new Error("No encrypted archive found for this account.");

    const local = buildLocalSyncModel();
    const merged = mergeSyncContinuityModels(local, remote);
    markPendingCarryoverAfterRemoteMerge(remote.emotionalContinuity);
    applySyncContinuityModel(merged);

    const syncedAt = new Date().toISOString();
    writeLastBackupAt(syncedAt);
    writeLastSyncedAt(syncedAt);
    dispatchSyncStatusChange();
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
