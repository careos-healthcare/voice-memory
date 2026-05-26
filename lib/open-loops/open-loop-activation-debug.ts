const DEBUG_STORAGE_KEY = "voicememory_open_loop_activation_debug";

export type OpenLoopActivationDebugPayload = Record<string, unknown>;

export function isOpenLoopActivationDebugEnabled(): boolean {
  if (typeof window === "undefined") {
    return process.env.NODE_ENV === "development";
  }
  try {
    if (localStorage.getItem(DEBUG_STORAGE_KEY) === "1") return true;
  } catch {
    /* ignore */
  }
  return process.env.NODE_ENV === "development";
}

export function setOpenLoopActivationDebugEnabled(enabled: boolean): void {
  if (typeof window === "undefined") return;
  try {
    if (enabled) {
      localStorage.setItem(DEBUG_STORAGE_KEY, "1");
    } else {
      localStorage.removeItem(DEBUG_STORAGE_KEY);
    }
  } catch {
    /* ignore */
  }
}

/** Temporary activation tracing — enable via localStorage or dev build. */
export function logOpenLoopActivationDebug(
  source: string,
  payload: OpenLoopActivationDebugPayload,
): void {
  if (!isOpenLoopActivationDebugEnabled()) return;
  console.info(`[open-loop-activation:${source}]`, payload);
}
