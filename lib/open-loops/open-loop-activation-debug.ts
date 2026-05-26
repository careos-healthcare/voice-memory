const DEBUG_STORAGE_KEY = "voicememory_open_loop_activation_debug";

export type OpenLoopActivationDebugPayload = Record<string, unknown>;

export function isOpenLoopActivationDebugEnabled(): boolean {
  if (process.env.NODE_ENV === "production") {
    if (typeof window === "undefined") return false;
    try {
      return localStorage.getItem(DEBUG_STORAGE_KEY) === "1";
    } catch {
      return false;
    }
  }
  if (typeof window === "undefined") return false;
  try {
    if (localStorage.getItem(DEBUG_STORAGE_KEY) === "1") return true;
    if (localStorage.getItem(DEBUG_STORAGE_KEY) === "0") return false;
  } catch {
    /* ignore */
  }
  return false;
}

export function setOpenLoopActivationDebugEnabled(enabled: boolean): void {
  if (typeof window === "undefined") return;
  try {
    if (enabled) {
      localStorage.setItem(DEBUG_STORAGE_KEY, "1");
    } else {
      localStorage.setItem(DEBUG_STORAGE_KEY, "0");
    }
  } catch {
    /* ignore */
  }
}

export function logOpenLoopActivationDebug(
  source: string,
  payload: OpenLoopActivationDebugPayload,
): void {
  if (!isOpenLoopActivationDebugEnabled()) return;
  console.info(`[open-loop-activation:${source}]`, payload);
}
