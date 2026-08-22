import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";

const FAST_CAPTURE_READY_KEY = "voicememory_fast_capture_ready";
const MIC_GRANTED_KEY = "voicememory_mic_granted_session";
const APP_OPEN_KEY = "voicememory_capture_app_open_at";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Internal — recorder shell is warm enough for mic-first render. */
export function markFastCaptureReady(): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  sessionStorage.setItem(FAST_CAPTURE_READY_KEY, "1");
}

export function isFastCaptureReady(): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(FAST_CAPTURE_READY_KEY) === "1";
}

/** Earliest capture-route land — used for app_open → mic latency. */
export function markAppOpenForCapture(): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  if (!sessionStorage.getItem(APP_OPEN_KEY)) {
    sessionStorage.setItem(APP_OPEN_KEY, String(Date.now()));
  }
  markFastCaptureReady();
}

export function getAppOpenTimestamp(): number | null {
  if (!isBrowser()) return null;
  const raw = sessionStorage.getItem(APP_OPEN_KEY);
  if (!raw) return null;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : null;
}

export function markMicrophonePermissionGranted(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(MIC_GRANTED_KEY, "1");
}

/** Sync check — session remembers a successful mic grant this session. */
export function hasKnownMicrophoneGrant(): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(MIC_GRANTED_KEY) === "1";
}

/** Autostart only when permission is already granted (no permission dialog on open). */
export async function isMicrophonePermissionGranted(): Promise<boolean> {
  if (!isBrowser()) return false;
  if (hasKnownMicrophoneGrant()) return true;
  try {
    const permissions = navigator.permissions;
    if (!permissions?.query) return false;
    const status = await permissions.query({
      name: "microphone" as PermissionName,
    });
    if (status.state === "granted") {
      markMicrophonePermissionGranted();
      return true;
    }
    return false;
  } catch {
    return false;
  }
}

export function shouldAutoStartWithMicPermission(wantsAutoStart: boolean): boolean {
  if (!wantsAutoStart) return false;
  return hasKnownMicrophoneGrant();
}

/** Defer presentation, resurfacing, and storage hydration on capture routes. */
export function shouldDeferNonEssentialHydration(route: string): boolean {
  return route === "record" || route === "home_mic_centric" || route.startsWith("capture");
}

/** Hint service worker to warm `/record` shell (fire-and-forget). */
export function warmFastCaptureShell(): void {
  if (!isBrowser() || !("serviceWorker" in navigator)) return;
  void navigator.serviceWorker.ready.then((registration) => {
    registration.active?.postMessage({ type: "warm-capture", path: "/record" });
  });
}
