import { getAllEntries } from "@/lib/storage";
import { readSessionRetentionSnapshot } from "@/lib/retention/session-retention";

const RECORDER_SURFACE_KEY = "voicememory_recorder_surface";
const MIC_REQUEST_KEY = "voicememory_mic_permission_request";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Completed reflections with transcript (not pending-only). */
export function countCompletedReflections(): number {
  if (!isBrowser()) return 0;
  return getAllEntries().filter(
    (entry) =>
      entry.reflectionPending !== true &&
      typeof entry.transcript === "string" &&
      entry.transcript.trim().length > 0,
  ).length;
}

/** User earned install prompt: 2+ saves or second session. */
export function hasInstallPromptEligibility(): boolean {
  if (!isBrowser()) return false;
  if (countCompletedReflections() >= 2) return true;
  const snap = readSessionRetentionSnapshot();
  if (snap.sessionCount >= 2) return true;
  return Boolean(snap.onceFlags.second_session_started);
}

export function setRecorderSurfaceActive(active: boolean): void {
  if (!isBrowser()) return;
  if (active) {
    sessionStorage.setItem(RECORDER_SURFACE_KEY, "1");
  } else {
    sessionStorage.removeItem(RECORDER_SURFACE_KEY);
  }
}

export function isRecorderSurfaceActive(): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(RECORDER_SURFACE_KEY) === "1";
}

export function markMicPermissionRequestActive(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(MIC_REQUEST_KEY, "1");
}

export function clearMicPermissionRequestActive(): void {
  if (!isBrowser()) return;
  sessionStorage.removeItem(MIC_REQUEST_KEY);
}

export function isMicPermissionRequestActive(): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(MIC_REQUEST_KEY) === "1";
}

const BLOCKED_PREFIXES = ["/record", "/entry/"];

export function isInstallPromptBlockedRoute(pathname: string | null): boolean {
  if (!pathname) return false;
  if (BLOCKED_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(prefix))) {
    return true;
  }
  return false;
}

export function shouldShowInstallPrompt(pathname: string | null): boolean {
  if (!isBrowser()) return false;
  if (!hasInstallPromptEligibility()) return false;
  if (isInstallPromptBlockedRoute(pathname)) return false;
  if (isRecorderSurfaceActive()) return false;
  if (isMicPermissionRequestActive()) return false;
  return true;
}
