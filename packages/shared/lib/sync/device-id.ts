const DEVICE_ID_KEY = "voicememory_sync_device_id";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Stable per-browser device identifier for sync conflict resolution. */
export function getOrCreateDeviceId(): string {
  if (!isBrowser()) return "server";

  const existing = localStorage.getItem(DEVICE_ID_KEY);
  if (existing?.trim()) return existing.trim();

  const id = crypto.randomUUID();
  localStorage.setItem(DEVICE_ID_KEY, id);
  return id;
}

export function readDeviceId(): string | null {
  if (!isBrowser()) return null;
  return localStorage.getItem(DEVICE_ID_KEY);
}
