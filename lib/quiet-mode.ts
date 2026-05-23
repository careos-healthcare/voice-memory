const QUIET_MODE_KEY = "voicememory_quiet_mode";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function isQuietModeEnabled(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(QUIET_MODE_KEY) === "1";
}

export function setQuietModeEnabled(enabled: boolean): void {
  if (!isBrowser()) return;
  if (enabled) {
    localStorage.setItem(QUIET_MODE_KEY, "1");
  } else {
    localStorage.removeItem(QUIET_MODE_KEY);
  }
  window.dispatchEvent(new CustomEvent("voicememory:quiet-mode"));
}

export function getQuietLimits(quiet: boolean): {
  callbacks: number;
  changes: number;
  landmarks: number;
  observations: number;
} {
  if (quiet) {
    return { callbacks: 1, changes: 1, landmarks: 1, observations: 1 };
  }
  return { callbacks: 3, changes: 3, landmarks: 2, observations: 3 };
}
