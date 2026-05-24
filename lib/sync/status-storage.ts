export const SYNC_STATUS_EVENT = "voicememory:sync-status";
export const SYNC_LAST_BACKUP_KEY = "voicememory_sync_last_backup_at";
export const SYNC_LAST_ERROR_KEY = "voicememory_sync_last_error";

export function readLastBackupAt(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(SYNC_LAST_BACKUP_KEY);
}

export function writeLastBackupAt(iso: string): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(SYNC_LAST_BACKUP_KEY, iso);
}

export function readLastSyncError(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(SYNC_LAST_ERROR_KEY);
}

export function writeLastSyncError(message: string | null): void {
  if (typeof window === "undefined") return;
  if (!message) {
    localStorage.removeItem(SYNC_LAST_ERROR_KEY);
    return;
  }
  localStorage.setItem(SYNC_LAST_ERROR_KEY, message);
}

export function dispatchSyncStatusChange(): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent(SYNC_STATUS_EVENT));
}
