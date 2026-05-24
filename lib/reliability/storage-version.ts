export const STORAGE_VERSION_KEY = "voicememory_storage_version";
export const STORAGE_META_KEY = "voicememory_storage_meta";

/** Increment when migrations change stored shape. */
export const CURRENT_STORAGE_VERSION = 1;

export function readStorageVersion(): number {
  if (typeof window === "undefined") return CURRENT_STORAGE_VERSION;

  try {
    const raw = localStorage.getItem(STORAGE_VERSION_KEY);
    if (!raw) return 0;
    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
  } catch {
    return 0;
  }
}

export function writeStorageVersion(version: number): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(STORAGE_VERSION_KEY, String(version));
}
