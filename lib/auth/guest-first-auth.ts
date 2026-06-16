import {
  ensureCaptureAttested,
  resetCaptureAttestCache,
} from "@/lib/client/capture-attest";
import { trackLocalEvent } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { AuthTriggerReason } from "@/types/auth-trigger";
import { syncArchiveIfSignedIn } from "@/lib/sync/client";
import { getOrCreateDeviceId } from "@/lib/sync/device-id";

export const GUEST_FIRST_AUTH_EVENTS = {
  guestModeStarted: "guest_mode_started",
  protectArchiveBannerSeen: "protect_archive_banner_seen",
  protectArchiveClicked: "protect_archive_clicked",
  authPromptShown: "auth_prompt_shown",
  authVerified: "auth_verified",
} as const;

const GUEST_MODE_STARTED_KEY = "voicememory_guest_mode_started";
const PROTECT_BANNER_DISMISSED_KEY = "voicememory_protect_archive_banner_dismissed";

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

export function hasLocalArchiveOnDevice(): boolean {
  return getMemoryEligibleEntries().length > 0;
}

export function hasEligibleReflectionOnDevice(): boolean {
  return getMemoryEligibleEntries().some(
    (e) =>
      e.reflectionPending !== true &&
      typeof e.transcript === "string" &&
      e.transcript.trim().length > 0,
  );
}

/** Mark guest mode once per browser — recording works via device attest without email. */
export function markGuestModeStartedIfNeeded(isSignedIn: boolean): void {
  const store = getStorage();
  if (!store || isSignedIn) return;
  if (store.getItem(GUEST_MODE_STARTED_KEY) === "1") return;
  store.setItem(GUEST_MODE_STARTED_KEY, "1");
  trackLocalEvent(GUEST_FIRST_AUTH_EVENTS.guestModeStarted, {});
}

export function isGuestModeActive(isSignedIn: boolean): boolean {
  if (isSignedIn) return false;
  const store = getStorage();
  if (!store) return true;
  return store.getItem(GUEST_MODE_STARTED_KEY) === "1";
}

export function dismissProtectArchiveBanner(): void {
  getStorage()?.setItem(PROTECT_BANNER_DISMISSED_KEY, "1");
}

export function shouldShowProtectArchiveBanner(isSignedIn: boolean): boolean {
  if (isSignedIn) return false;
  if (!hasLocalArchiveOnDevice()) return false;
  if (!hasEligibleReflectionOnDevice()) return false;
  return getStorage()?.getItem(PROTECT_BANNER_DISMISSED_KEY) !== "1";
}

export function trackProtectArchiveBannerSeen(): void {
  trackLocalEvent(GUEST_FIRST_AUTH_EVENTS.protectArchiveBannerSeen, {});
}

export function trackProtectArchiveClicked(): void {
  trackLocalEvent(GUEST_FIRST_AUTH_EVENTS.protectArchiveClicked, {});
}

export function trackAuthPromptShown(reason: AuthTriggerReason): void {
  trackLocalEvent(GUEST_FIRST_AUTH_EVENTS.authPromptShown, { reason });
}

export function trackAuthVerified(reason: AuthTriggerReason): void {
  trackLocalEvent(GUEST_FIRST_AUTH_EVENTS.authVerified, { reason });
}

/** After verify: refresh device attest + push encrypted backup. */
export async function registerDeviceAfterSignIn(): Promise<boolean> {
  if (typeof window === "undefined") return false;

  resetCaptureAttestCache();
  getOrCreateDeviceId();

  const attested = await ensureCaptureAttested();
  const synced = await syncArchiveIfSignedIn();
  return attested && synced;
}
