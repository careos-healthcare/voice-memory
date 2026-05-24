import { trackLocalEvent } from "@/lib/local-analytics";
import type { VisualTone } from "@/types/personalization";

export const AMBIENT_MODE_ENABLED = "ambient_mode_enabled";
export const TONE_AUTO_CHANGED = "tone_auto_changed";
export const CONTRAST_SOFTENED = "contrast_softened";
export const USER_OVERRode_TONE = "user_overrode_tone";

export function trackAmbientModeEnabled(): void {
  trackLocalEvent(AMBIENT_MODE_ENABLED);
}

export function trackToneAutoChanged(from: VisualTone, to: VisualTone, reason: string): void {
  trackLocalEvent(TONE_AUTO_CHANGED, { from, to, reason });
}

export function trackContrastSoftened(reason: string): void {
  trackLocalEvent(CONTRAST_SOFTENED, { reason });
}

export function trackUserOverrodeTone(tone: VisualTone): void {
  trackLocalEvent(USER_OVERRode_TONE, { tone });
}
