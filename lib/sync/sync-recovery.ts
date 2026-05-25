import { clearLastSyncedAt } from "@/lib/sync/sync-metadata";
import { syncWarn } from "@/lib/sync/sync-log";
import { writeLastSyncError } from "@/lib/sync/status-storage";
import {
  mapSyncErrorToUserMessage,
  SyncClientError,
  toSyncClientError,
} from "@/lib/sync/sync-errors";

/** Clear remote sync cursor so the next upload can replace corrupt server state. */
export function recoverFromCorruptRemoteState(reason: string): void {
  clearLastSyncedAt();
  syncWarn("Recovering from corrupt remote backup — preserving local archive", { reason });
}

export function writeFriendlySyncError(error: unknown): void {
  const message = mapSyncErrorToUserMessage(error);
  writeLastSyncError(message);
}

export function isRecoverableRemoteCorruption(error: unknown): boolean {
  if (!(error instanceof SyncClientError)) {
    const mapped = toSyncClientError(error, "REMOTE_BACKUP_CORRUPT");
    return isRecoverableRemoteCorruption(mapped);
  }
  return [
    "EMPTY_REMOTE_PAYLOAD",
    "INVALID_REMOTE_JSON",
    "INVALID_ENCRYPTED_ENVELOPE",
    "DECRYPT_FAILED",
    "UNSUPPORTED_ENCRYPTION_VERSION",
    "REMOTE_BACKUP_CORRUPT",
    "NON_JSON_RESPONSE",
  ].includes(error.code);
}
