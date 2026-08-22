const LAST_SYNCED_KEY = "voicememory_sync_last_synced_at";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function readLastSyncedAt(): string | null {
  if (!isBrowser()) return null;
  return localStorage.getItem(LAST_SYNCED_KEY);
}

export function writeLastSyncedAt(iso: string): void {
  if (!isBrowser()) return;
  localStorage.setItem(LAST_SYNCED_KEY, iso);
}

export function clearLastSyncedAt(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(LAST_SYNCED_KEY);
}
