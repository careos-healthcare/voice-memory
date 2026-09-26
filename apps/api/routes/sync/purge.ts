import { getUserAudioStorageProvider } from "@/lib/user/user-audio-storage";
import { shouldUsePostgresStorage, withDbTransaction } from "@/lib/server/db";
import { deleteMobilePushDevicesForUser } from "@/lib/push/mobile-push-devices";
import { dropAccountSyncState } from "@/lib/server/sync-records";
import { deleteSyncDataForUser } from "@/lib/server/sync-store";

export interface AccountSyncPurgeResult {
  blobs: number;
  mediaChunks: number;
  devices: number;
}

const accountTables = [
  `DELETE FROM sync_blobs WHERE user_id = $1`,
  `DELETE FROM sync_records WHERE user_id = $1`,
  `DELETE FROM sync_change_log WHERE user_id = $1`,
  `DELETE FROM sync_keys WHERE user_id = $1`,
  `DELETE FROM sync_pair_relays WHERE user_id = $1`,
  `DELETE FROM mobile_push_devices WHERE user_id = $1`,
] as const;

/**
 * Permanently drops encrypted blobs, media chunks, and device metadata for
 * one account. A second call finds nothing left to delete.
 */
export async function purgeAccountSyncCopy(
  userId: string,
): Promise<AccountSyncPurgeResult> {
  const accountId = userId.trim();
  if (!accountId) {
    throw new Error("account id is required");
  }

  let blobs = 0;
  let devices = 0;
  if (shouldUsePostgresStorage()) {
    const counts = await withDbTransaction(async (client) => {
      const removed: number[] = [];
      for (const sql of accountTables) {
        const result = await client.query(sql, [accountId]);
        removed.push(result.rowCount ?? 0);
      }
      return removed;
    });
    blobs = counts[0] + counts[1];
    devices = counts[5];
  }

  const blobStore = await deleteSyncDataForUser(accountId);
  blobs += blobStore.count;
  if (!shouldUsePostgresStorage()) {
    devices += await deleteMobilePushDevicesForUser(accountId);
  }

  const audio = await getUserAudioStorageProvider().deleteUserAudioPrefix(accountId);
  if (!audio.ok) {
    throw new Error("Blob storage purge did not succeed.");
  }

  const memory = dropAccountSyncState(accountId);
  return {
    blobs: blobs + memory.records,
    mediaChunks: memory.mediaChunks + audio.deletedCount,
    devices: devices + memory.devices,
  };
}
