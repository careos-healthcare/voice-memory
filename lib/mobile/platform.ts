/**
 * Platform abstraction for web PWA vs Capacitor native wrapper.
 * Capacitor shell loads the hosted Next.js app; plugins are opt-in only.
 */

export type MobileRuntime = "web" | "pwa" | "capacitor" | "unknown";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readCapacitorGlobal(): { isNativePlatform?: () => boolean } | null {
  if (!isBrowser()) return null;
  const cap = (window as Window & { Capacitor?: { isNativePlatform?: () => boolean } })
    .Capacitor;
  return cap ?? null;
}

export function getMobileRuntime(): MobileRuntime {
  if (!isBrowser()) return "unknown";
  if (readCapacitorGlobal()?.isNativePlatform?.()) return "capacitor";
  if (isPWA()) return "pwa";
  return "web";
}

/** True when running inside the Capacitor iOS/Android shell. */
export function isNativeWrapper(): boolean {
  return getMobileRuntime() === "capacitor";
}

export function isPWA(): boolean {
  if (!isBrowser()) return false;
  const standalone =
    window.matchMedia("(display-mode: standalone)").matches ||
    window.matchMedia("(display-mode: fullscreen)").matches;
  const iosStandalone = (navigator as Navigator & { standalone?: boolean }).standalone === true;
  return standalone || iosStandalone;
}

export function isIOS(): boolean {
  if (!isBrowser()) return false;
  return /iPad|iPhone|iPod/.test(navigator.userAgent);
}

export function isAndroid(): boolean {
  if (!isBrowser()) return false;
  return /Android/i.test(navigator.userAgent);
}

/** Web Push only — native push is not implemented (no fake readiness). */
export function supportsPush(): boolean {
  if (!isBrowser()) return false;
  if (isNativeWrapper()) return false;
  return "Notification" in window && "serviceWorker" in navigator && "PushManager" in window;
}

/** Background audio while screen locked — not implemented on any platform yet. */
export function supportsBackgroundAudio(): boolean {
  if (isNativeWrapper()) return false;
  if (!isBrowser()) return false;
  return "mediaSession" in navigator;
}

export function prefersReducedMotion(): boolean {
  if (!isBrowser()) return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}
