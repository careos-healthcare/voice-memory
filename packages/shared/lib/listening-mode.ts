const LISTENING_MODE_KEY = "voicememory_listening_mode";

export const LISTENING_MODE_CHANGE_EVENT = "voicememory:listening-mode";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** When on, recordings save without immediate reflection — interpret later. */
export function isListeningModeEnabled(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(LISTENING_MODE_KEY) === "1";
}

export function setListeningModeEnabled(enabled: boolean): void {
  if (!isBrowser()) return;
  if (enabled) {
    localStorage.setItem(LISTENING_MODE_KEY, "1");
  } else {
    localStorage.removeItem(LISTENING_MODE_KEY);
  }
  window.dispatchEvent(new CustomEvent(LISTENING_MODE_CHANGE_EVENT));
}

export const LISTENING_SAVED_COPY = "Saved. We'll let this sit.";
