const QUICK_KEY = "voicememory_quick_reflection";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Fastest emotional path — recorder only, transcript visible, instant save. */
export function isQuickReflectionEnabled(): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(QUICK_KEY) === "1";
}

export function enableQuickReflectionMode(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(QUICK_KEY, "1");
}

export function disableQuickReflectionMode(): void {
  if (!isBrowser()) return;
  sessionStorage.removeItem(QUICK_KEY);
}

export function toggleQuickReflectionMode(): boolean {
  if (isQuickReflectionEnabled()) {
    disableQuickReflectionMode();
    return false;
  }
  enableQuickReflectionMode();
  return true;
}
