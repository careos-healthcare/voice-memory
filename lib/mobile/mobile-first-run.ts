import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";
import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";

export const MOBILE_FIRST_RUN_TAGLINE = LANDING_3_DAY_CHALLENGE.hero;

export const MOBILE_FIRST_RUN_PRIVACY =
  "Your words stay on this device. Sign in only if you want encrypted backup.";

export function isNarrowMobileViewport(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(max-width: 640px)").matches;
}

/** First mobile visit before any completed reflection — compress homepage. */
export function isMobileFirstRunHome(): boolean {
  if (!isNarrowMobileViewport()) return false;
  return countCompletedReflections() === 0;
}

/** Mobile with at least one save — mic-first, rhythm below recorder. */
export function isMobileReturningHome(): boolean {
  if (!isNarrowMobileViewport()) return false;
  return countCompletedReflections() >= 1;
}
