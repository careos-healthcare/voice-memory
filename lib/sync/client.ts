import { buildLocalArchiveBundle, restoreLocalArchiveBundle } from "@/lib/sync/archive-bundle";
import {
  buildEncryptedAudioBackupPlan,
  readAudioBlobForBackup,
} from "@/lib/sync/audio-backup";
import {
  fetchAccountSession,
  markSyncFinished,
  markSyncStarted,
} from "@/lib/sync/account-client";
import {
  encryptBinaryPayload,
  encryptJsonPayload,
  decryptJsonPayload,
  ensureSyncMasterKey,
} from "@/lib/sync/encryption";
import {
  dispatchSyncStatusChange,
  writeLastBackupAt,
  writeLastSyncError,
} from "@/lib/sync/status-storage";
import type { EncryptedPayload, SyncArchiveBundle } from "@/types/sync";

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

/** Encrypt and upload journal, bookmarks, settings, and review labels. */
export async function syncArchiveIfSignedIn(): Promise<boolean> {
  const session = await fetchAccountSession();
  if (!session) return false;

  markSyncStarted();
  writeLastSyncError(null);

  try {
    await ensureSyncMasterKey();
    const bundle = buildLocalArchiveBundle();

    const encryptedCore = await encryptJsonPayload(bundle);
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

    writeLastBackupAt(new Date().toISOString());
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

/** Pull encrypted archive and restore locally after decryption. */
export async function restoreArchiveFromEncryptedBackup(): Promise<void> {
  const session = await fetchAccountSession();
  if (!session) throw new Error("Sign in to restore your archive.");

  markSyncStarted();
  writeLastSyncError(null);

  try {
    const response = await fetch("/api/sync/pull", { cache: "no-store" });
    const data = (await response.json()) as {
      error?: string;
      blobs?: Array<{
        id: string;
        type: string;
        encrypted: EncryptedPayload;
      }>;
    };

    if (!response.ok) throw new Error(data.error ?? "Could not fetch encrypted backup.");

    const core = data.blobs?.find((blob) => blob.id === CORE_BLOB_ID);
    if (!core) throw new Error("No encrypted archive found for this account.");

    const bundle = await decryptJsonPayload<SyncArchiveBundle>(core.encrypted);
    restoreLocalArchiveBundle(bundle);
    writeLastBackupAt(new Date().toISOString());
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
