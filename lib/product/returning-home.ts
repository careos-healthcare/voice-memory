import { isOnboardingDismissed } from "@/lib/onboarding";
import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";

const ARCHIVE_BELIEF_REDIRECT_SESSION_KEY = "voicememory_archive_belief_home_redirected";
/** @deprecated use ARCHIVE_BELIEF_REDIRECT_SESSION_KEY */
const DISCOVER_REDIRECT_SESSION_KEY = ARCHIVE_BELIEF_REDIRECT_SESSION_KEY;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Returning user = finished activation onboarding and has at least one saved reflection. */
export function isReturningProductUser(): boolean {
  if (!isBrowser()) return false;
  if (!isOnboardingDismissed()) return false;
  return countCompletedReflections() >= 1;
}

export function hasArchiveBeliefHomeRedirectedThisSession(): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(ARCHIVE_BELIEF_REDIRECT_SESSION_KEY) === "1";
}

export function markArchiveBeliefHomeRedirected(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(ARCHIVE_BELIEF_REDIRECT_SESSION_KEY, "1");
}

export function clearArchiveBeliefHomeRedirectForEval(): void {
  if (!isBrowser()) return;
  sessionStorage.removeItem(ARCHIVE_BELIEF_REDIRECT_SESSION_KEY);
}

/** Desktop returning visits: prefer /archive-belief once per session (not on forced stay). */
export function shouldAutoRedirectToArchiveBelief(options?: {
  stayOnHome?: boolean;
  narrowMobile?: boolean;
}): boolean {
  if (!isBrowser()) return false;
  if (options?.stayOnHome) return false;
  if (options?.narrowMobile) return false;
  if (!isReturningProductUser()) return false;
  if (hasArchiveBeliefHomeRedirectedThisSession()) return false;
  return true;
}

export function preferredHomeHref(): "/" | "/archive-belief" | "/record" {
  return isReturningProductUser() ? "/archive-belief" : "/";
}

/** Returning users should land on Archive, not record/discover/memory. */
export function preferredReturningLandingHref(): "/archive-belief" {
  return "/archive-belief";
}

/** @deprecated use archive-belief redirect */
export function hasDiscoverHomeRedirectedThisSession(): boolean {
  return hasArchiveBeliefHomeRedirectedThisSession();
}

export function markDiscoverHomeRedirected(): void {
  markArchiveBeliefHomeRedirected();
}

export function clearDiscoverHomeRedirectForEval(): void {
  clearArchiveBeliefHomeRedirectForEval();
}

export function shouldAutoRedirectToDiscover(options?: {
  stayOnHome?: boolean;
  narrowMobile?: boolean;
}): boolean {
  return shouldAutoRedirectToArchiveBelief(options);
}
