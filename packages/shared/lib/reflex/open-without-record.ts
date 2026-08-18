import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";

const SESSION_OPENS_KEY = "voicememory_reflex_session_opens";
const SESSION_RECORDED_KEY = "voicememory_reflex_session_recorded";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Session opens without a completed recording — triggers silence-first reflex UI. */
export function recordReflexAppOpen(): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  const opens = Number(sessionStorage.getItem(SESSION_OPENS_KEY) ?? "0") + 1;
  sessionStorage.setItem(SESSION_OPENS_KEY, String(opens));
}

export function recordReflexSessionRecording(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(SESSION_RECORDED_KEY, "1");
  sessionStorage.setItem(SESSION_OPENS_KEY, "0");
}

export function shouldActivateReflexSilenceFirst(): boolean {
  if (!isBrowser()) return false;
  if (sessionStorage.getItem(SESSION_RECORDED_KEY) === "1") return false;
  const opens = Number(sessionStorage.getItem(SESSION_OPENS_KEY) ?? "0");
  return opens >= 3;
}
