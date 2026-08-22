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
import { markPendingCarryoverAfterRemoteMerge } from "@/lib/sync/cross-device-continuity";
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
import {
  readResponseJson,
  type SyncManifestPayload,
  type SyncPullPayload,
  type SyncPushPayload,
} from "@/lib/sync/parse-response";
import { writeLastSyncedAt } from "@/lib/sync/sync-metadata";
import { SyncClientError } from "@/lib/sync/sync-errors";
import {
  isRecoverableRemoteCorruption,
  recoverFromCorruptRemoteState,
  writeFriendlySyncError,
} from "@/lib/sync/sync-recovery";
import { syncWarn } from "@/lib/sync/sync-log";
import { validateRemoteBlobRecord } from "@/lib/sync/validate-remote";
import type { EncryptedPayload } from "@/types/sync";
import type { SyncContinuityModel } from "@/types/sync-continuity";
import type { RestorePreview } from "@/types/sync-health";

const CORE_BLOB_ID = "archive-core";

const EMPTY_PULL: SyncPullPayload = { ok: true, blobs: [] };
const EMPTY_PUSH: SyncPushPayload = { ok: false, error: "Encrypted backup failed.", code: "SYNC_PUSH_FAILED" };

export interface PullCoreResult {
  encrypted: EncryptedPayload | null;
  model: SyncContinuityModel | null;
  corrupt: boolean;
  missing: boolean;
}

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

  const data = await readResponseJson<SyncPushPayload>(response, EMPTY_PUSH, {
    routeLabel: "sync/push",
  });

  if (!data.ok) {
    throw new SyncClientError(
      (data.code as SyncClientError["code"]) ?? "SYNC_PUSH_FAILED",
      typeof data.error === "string"
        ? data.error
        : (data.error?.message ?? "Encrypted backup could not be saved."),
    );
  }
}

async function pullEncryptedCoreBlobRaw(): Promise<PullCoreResult> {
  const response = await fetch("/api/sync/pull", { cache: "no-store" });

  let data: SyncPullPayload;
  try {
    data = await readResponseJson<SyncPullPayload>(response, EMPTY_PULL, {
      routeLabel: "sync/pull",
    });
  } catch (error) {
    syncWarn("Pull failed before blob parse", { error });
    return { encrypted: null, model: null, corrupt: true, missing: false };
  }

  if (!data.ok) {
    return { encrypted: null, model: null, corrupt: false, missing: true };
  }

  const core = data.blobs?.find(
    (blob: NonNullable<SyncPullPayload["blobs"]>[number]) => blob.id === CORE_BLOB_ID,
  );
  if (!core) {
    return { encrypted: null, model: null, corrupt: false, missing: true };
  }

  const blobValidation = validateRemoteBlobRecord({
    id: core.id,
    updatedAt: core.updatedAt,
    encrypted: core.encrypted as EncryptedPayload,
  });
  const encrypted = core.encrypted as EncryptedPayload;

  if (!blobValidation.valid) {
    syncWarn("Remote core blob envelope invalid", { issues: blobValidation.issues });
    return { encrypted, model: null, corrupt: true, missing: false };
  }

  try {
    const payload = await decryptJsonPayload<unknown>(encrypted);
    const model = normalizeRemoteSyncPayload(payload, getOrCreateDeviceId());
    return { encrypted, model, corrupt: false, missing: false };
  } catch (error) {
    syncWarn("Remote core blob decrypt failed", {
      code: error instanceof SyncClientError ? error.code : "DECRYPT_FAILED",
    });
    return { encrypted, model: null, corrupt: true, missing: false };
  }
}

/** Preview encrypted restore before applying — local archive is not modified. */
export async function previewRestoreFromEncryptedBackup(): Promise<RestorePreview> {
  const session = await fetchAccountSession();
  if (!session) throw new SyncClientError("SYNC_AUTH_REQUIRED", "Sign in to restore your archive.");

  await ensureSyncMasterKey();

  const pull = await pullEncryptedCoreBlobRaw();
  if (!pull.model) {
    if (pull.corrupt) {
      throw new SyncClientError(
        "REMOTE_BACKUP_CORRUPT",
        "Encrypted backup could not be verified.",
      );
    }
    throw new SyncClientError("NO_REMOTE_BACKUP", "No backup found yet.");
  }

  const local = buildLocalSyncModel();
  return buildRestorePreview(local, pull.model);
}

/** Apply a previously previewed merge — keeps pre-restore snapshot on failure. */
export async function applyEncryptedRestoreFromPreview(
  preview: RestorePreview,
): Promise<void> {
  if (!preview.safeToApply) {
    throw new Error("Restore preview is not safe to apply.");
  }

  const pull = await pullEncryptedCoreBlobRaw();
  if (!pull.model) {
    throw new SyncClientError("NO_REMOTE_BACKUP", "Encrypted backup is no longer available.");
  }

  const local = buildLocalSyncModel();
  const merged = mergeSyncContinuityModelsWithResult(local, pull.model).model;

  snapshotPreRestoreArchive();

  try {
    await ensureSyncMasterKey();
    markPendingCarryoverAfterRemoteMerge(pull.model.emotionalContinuity);
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
    const pull = await pullEncryptedCoreBlobRaw();

    let merged = local;
    let remoteForCarryover: SyncContinuityModel | null = null;

    if (pull.corrupt) {
      recoverFromCorruptRemoteState("remote_core_corrupt");
      merged = local;
    } else if (pull.model) {
      remoteForCarryover = pull.model;
      merged = mergeSyncContinuityModelsWithResult(local, pull.model).model;
    } else if (pull.missing) {
      syncWarn("No remote backup yet — uploading local archive");
      merged = local;
    }

    if (remoteForCarryover) {
      markPendingCarryoverAfterRemoteMerge(remoteForCarryover.emotionalContinuity);
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
    if (isRecoverableRemoteCorruption(error)) {
      recoverFromCorruptRemoteState("sync_upload_after_corruption");
      try {
        const local = buildLocalSyncModel();
        applySyncContinuityModel(local);
        const encryptedCore = await encryptJsonPayload(toEncryptedSyncPayload(local));
        await pushEncryptedBlob({
          id: CORE_BLOB_ID,
          type: "journal_snapshot",
          encrypted: encryptedCore,
        });
        const syncedAt = new Date().toISOString();
        writeLastBackupAt(syncedAt);
        writeLastSyncedAt(syncedAt);
        dispatchSyncStatusChange();
        return true;
      } catch (retryError) {
        writeFriendlySyncError(retryError);
      }
    } else {
      writeFriendlySyncError(error);
    }
    dispatchSyncStatusChange();
    return false;
  } finally {
    markSyncFinished();
  }
}

/** Pull encrypted archive, preview merge, then apply — never deletes local on failure. */
export async function restoreArchiveFromEncryptedBackup(): Promise<RestorePreview> {
  const session = await fetchAccountSession();
  if (!session) throw new SyncClientError("SYNC_AUTH_REQUIRED", "Sign in to restore your archive.");

  markSyncStarted();
  writeLastSyncError(null);

  try {
    await ensureSyncMasterKey();
    const preview = await previewRestoreFromEncryptedBackup();
    await applyEncryptedRestoreFromPreview(preview);
    return preview;
  } catch (error) {
    writeFriendlySyncError(error);
    dispatchSyncStatusChange();
    throw error;
  } finally {
    markSyncFinished();
  }
}

export async function fetchSyncManifest() {
  const response = await fetch("/api/sync/manifest", { cache: "no-store" });
  if (!response.ok) return null;

  const data = await readResponseJson<SyncManifestPayload>(
    response,
    { ok: true },
    { routeLabel: "sync/manifest" },
  );
  return data.ok ? data.manifest ?? null : null;
}

export async function inspectRemoteSyncHealth(): Promise<{
  corrupted: boolean;
  entryCount: number | null;
}> {
  const pull = await pullEncryptedCoreBlobRaw();
  const inspection = await inspectRemoteCoreBlob(pull.encrypted, decryptJsonPayload);
  return {
    corrupted: pull.corrupt || inspection.corrupted,
    entryCount: inspection.entryCount,
  };
}
