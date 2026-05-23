const FULL_DETAIL_KEY = "voicememory_full_detail";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Quiet memory view is the default. Full detail is opt-in via Settings. */
export function isQuietModeEnabled(): boolean {
  if (!isBrowser()) return true;
  return localStorage.getItem(FULL_DETAIL_KEY) !== "1";
}

export function isFullDetailEnabled(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(FULL_DETAIL_KEY) === "1";
}

export function setFullDetailEnabled(enabled: boolean): void {
  if (!isBrowser()) return;
  if (enabled) {
    localStorage.setItem(FULL_DETAIL_KEY, "1");
  } else {
    localStorage.removeItem(FULL_DETAIL_KEY);
  }
  window.dispatchEvent(new CustomEvent("voicememory:quiet-mode"));
}

/** @deprecated use setFullDetailEnabled */
export function setQuietModeEnabled(enabled: boolean): void {
  setFullDetailEnabled(!enabled);
}

export function getQuietLimits(quiet: boolean): {
  callbacks: number;
  changes: number;
  landmarks: number;
  observations: number;
  notes: number;
  resurfacing: number;
  changeMoments: number;
  familiarity: number;
  rhythm: number;
} {
  if (quiet) {
    return {
      callbacks: 2,
      changes: 2,
      landmarks: 4,
      observations: 1,
      notes: 4,
      resurfacing: 1,
      changeMoments: 1,
      familiarity: 1,
      rhythm: 1,
    };
  }
  return {
    callbacks: 3,
    changes: 3,
    landmarks: 4,
    observations: 3,
    notes: 9,
    resurfacing: 2,
    changeMoments: 2,
    familiarity: 1,
    rhythm: 1,
  };
}
