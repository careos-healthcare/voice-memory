function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function pendingKey(key: string): string {
  return `${key}__pending`;
}

function backupKey(key: string): string {
  return `${key}__backup`;
}

/** Write JSON with a verify-then-swap pattern to reduce torn writes. */
export function safeSetJson(key: string, value: unknown): void {
  if (!isBrowser()) return;

  const serialized = JSON.stringify(value);
  const pending = pendingKey(key);

  localStorage.setItem(pending, serialized);

  const readBack = localStorage.getItem(pending);
  if (readBack !== serialized) {
    throw new Error(`Storage verify failed for ${key}`);
  }

  const existing = localStorage.getItem(key);
  if (existing !== null) {
    localStorage.setItem(backupKey(key), existing);
  }

  localStorage.setItem(key, serialized);
  localStorage.removeItem(pending);
}

export function safeGetJson<T>(key: string): T | null {
  if (!isBrowser()) return null;

  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    return JSON.parse(raw) as T;
  } catch {
    const backup = localStorage.getItem(backupKey(key));
    if (backup) {
      try {
        return JSON.parse(backup) as T;
      } catch {
        return null;
      }
    }
    return null;
  }
}

export function restoreFromBackup(key: string): boolean {
  if (!isBrowser()) return false;

  const backup = localStorage.getItem(backupKey(key));
  if (!backup) return false;

  try {
    JSON.parse(backup);
    localStorage.setItem(key, backup);
    return true;
  } catch {
    return false;
  }
}
