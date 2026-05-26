import { trackLocalEvent } from "@/lib/local-analytics";
import { isPWA, isNativeWrapper } from "@/lib/mobile/platform";

export const BEHAVIOR_EVENTS = {
  proPreviewEnabled: "pro_preview_enabled",
  installPromptShown: "install_prompt_shown",
  installPromptDismissed: "install_prompt_dismissed",
  installAccepted: "install_accepted",
  sessionDeviceContext: "session_device_context",
} as const;

const SESSION_DEVICE_KEY = "voicememory_behavior_device_logged";

function isMobileUserAgent(): boolean {
  if (typeof navigator === "undefined") return false;
  return /android|iphone|ipad|ipod|mobile/i.test(navigator.userAgent);
}

/** Once per browser session — device context for behavioral readout only. */
export function observeSessionDeviceContext(): void {
  if (typeof window === "undefined") return;
  if (sessionStorage.getItem(SESSION_DEVICE_KEY)) return;
  sessionStorage.setItem(SESSION_DEVICE_KEY, "1");
  trackLocalEvent(BEHAVIOR_EVENTS.sessionDeviceContext, {
    mobile: isMobileUserAgent() ? "1" : "0",
    pwa: isPWA() ? "1" : "0",
    nativeWrapper: isNativeWrapper() ? "1" : "0",
  });
}

export function trackProPreviewEnabled(source = "settings"): void {
  trackLocalEvent(BEHAVIOR_EVENTS.proPreviewEnabled, { source });
}

export function trackInstallPromptShown(): void {
  trackLocalEvent(BEHAVIOR_EVENTS.installPromptShown);
}

export function trackInstallPromptDismissed(): void {
  trackLocalEvent(BEHAVIOR_EVENTS.installPromptDismissed);
}

export function trackInstallAccepted(): void {
  trackLocalEvent(BEHAVIOR_EVENTS.installAccepted);
}
