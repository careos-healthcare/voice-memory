import { BLIND_SPOT_MIN_REFLECTIONS } from "@/lib/blind-spots/blind-spot-copy";
import {
  readEvolvingUnderstandingState,
  RETURN_TO_CHECK_ARCHIVE_HOURS,
} from "@/lib/metrics/evolving-understanding-events";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { AuthTriggerReason } from "@/types/auth-trigger";

export interface AuthTriggerContext {
  isSignedIn: boolean;
  reflectionCount: number;
}

const PROMPT_SHOWN_PREFIX = "voicememory_auth_prompt_shown_";

export function readAuthTriggerContext(isSignedIn: boolean): AuthTriggerContext {
  const entries = getMemoryEligibleEntries();
  const snapshot = buildArchiveValueSnapshot(entries);
  return {
    isSignedIn,
    reflectionCount: snapshot.reflectionCount,
  };
}

/** Email is for protecting value — never before the first reflection. */
export function shouldPromptForAuthTrigger(
  reason: AuthTriggerReason,
  ctx: AuthTriggerContext,
): boolean {
  if (ctx.isSignedIn) return false;
  if (ctx.reflectionCount < 1) return false;

  switch (reason) {
    case "protect_archive":
    case "sync_archive":
    case "export":
    case "cross_device":
    case "pro_paywall":
    case "keep_tracking_pro":
      return true;
    case "first_working_belief":
      return ctx.reflectionCount >= BLIND_SPOT_MIN_REFLECTIONS;
    case "archive_changed_return":
      return shouldOfferArchiveChangedReturnAuth(ctx);
    default:
      return false;
  }
}

export function shouldOfferArchiveChangedReturnAuth(ctx: AuthTriggerContext): boolean {
  if (ctx.isSignedIn || ctx.reflectionCount < BLIND_SPOT_MIN_REFLECTIONS) return false;

  const state = readEvolvingUnderstandingState();
  if (!state.firstWorkingTheorySeenAt) return false;

  const hoursSince =
    (Date.now() - new Date(state.firstWorkingTheorySeenAt).getTime()) /
    (60 * 60 * 1000);
  return hoursSince >= RETURN_TO_CHECK_ARCHIVE_HOURS;
}

export function hasAuthPromptBeenShown(reason: AuthTriggerReason): boolean {
  if (typeof window === "undefined") return true;
  return localStorage.getItem(`${PROMPT_SHOWN_PREFIX}${reason}`) === "1";
}

export function markAuthPromptShown(reason: AuthTriggerReason): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(`${PROMPT_SHOWN_PREFIX}${reason}`, "1");
}

export function shouldOfferFirstWorkingBeliefAuth(ctx: AuthTriggerContext): boolean {
  if (hasAuthPromptBeenShown("first_working_belief")) return false;
  return shouldPromptForAuthTrigger("first_working_belief", ctx);
}

export function shouldOfferArchiveChangedReturnPrompt(ctx: AuthTriggerContext): boolean {
  if (hasAuthPromptBeenShown("archive_changed_return")) return false;
  return shouldPromptForAuthTrigger("archive_changed_return", ctx);
}

export const AUTH_TRIGGER_COPY: Record<
  AuthTriggerReason,
  { title: string; lead: string; cta: string }
> = {
  protect_archive: {
    title: "Protect this archive",
    lead: "Sign in with email to encrypt a backup of what you have already built on this device.",
    cta: "Protect with email",
  },
  pro_paywall: {
    title: "Sign in for Pro",
    lead: "Checkout links your subscription to an account so your archive stays protected.",
    cta: "Continue with email",
  },
  sync_archive: {
    title: "Back up your archive",
    lead: "Email sign-in enables encrypted sync — your saved moments stay on this device until you choose to protect them.",
    cta: "Sign in to sync",
  },
  export: {
    title: "Export with a protected account",
    lead: "Sign in so exports stay tied to your archive and optional encrypted backup.",
    cta: "Sign in to export",
  },
  cross_device: {
    title: "Continue on another device",
    lead: "Sign in with email to pick up your archive where you left off.",
    cta: "Sign in to continue",
  },
  first_working_belief: {
    title: "Your archive has a working belief",
    lead: "Sign in to protect the belief your archive is starting to hold — not to keep recording.",
    cta: "Protect this belief",
  },
  archive_changed_return: {
    title: "See what your archive believes now",
    lead: "You came back after your archive may have shifted. Sign in to protect that history.",
    cta: "Protect archive",
  },
  keep_tracking_pro: {
    title: "Keep tracking with Pro",
    lead: "Sign in before upgrading so your evolving archive stays backed up.",
    cta: "Sign in to continue",
  },
};
