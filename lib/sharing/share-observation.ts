import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type { QuietShareSource, ShareObservationReport } from "@/types/sharing";

export const QUIET_SHARE_EVENT = "quiet_share";
export const QUIET_SHARE_PNG_EVENT = "quiet_share_png";
export const INVITE_OPEN_EVENT = "invite_open";
export const CREATOR_PREVIEW_COMPLETE_EVENT = "creator_preview_complete";
export const REVISIT_AFTER_SHARE_EVENT = "revisit_after_share";

const CREATOR_PREVIEW_KEY = "voicememory_creator_preview_complete";
const INVITE_RETURN_KEY = "voicememory_invite_return";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function trackQuietShare(input: {
  source: QuietShareSource;
  sourceId?: string;
  line: string;
  entryId?: string;
  callbackId?: string;
  copiedBefore?: boolean;
  format?: "text" | "png";
}): void {
  trackLocalEvent(input.format === "png" ? QUIET_SHARE_PNG_EVENT : QUIET_SHARE_EVENT, {
    source: input.source,
    sourceId: input.sourceId ?? "",
    line: input.line.slice(0, 120),
    entryId: input.entryId ?? "",
    callbackId: input.callbackId ?? "",
    copiedBefore: input.copiedBefore ? "1" : "0",
  });
}

export function trackInviteOpen(from?: string): void {
  trackLocalEvent(INVITE_OPEN_EVENT, { from: from ?? "direct" });
  if (isBrowser()) {
    sessionStorage.setItem(INVITE_RETURN_KEY, new Date().toISOString());
  }
}

export function trackCreatorPreviewComplete(): void {
  trackLocalEvent(CREATOR_PREVIEW_COMPLETE_EVENT);
  if (isBrowser()) {
    localStorage.setItem(CREATOR_PREVIEW_KEY, "1");
  }
}

export function hasCompletedCreatorPreview(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(CREATOR_PREVIEW_KEY) === "1";
}

export function trackRevisitAfterShare(entryId: string, sourceId?: string): void {
  trackLocalEvent(REVISIT_AFTER_SHARE_EVENT, {
    entryId,
    sourceId: sourceId ?? "",
  });
}

export function maybeTrackRevisitAfterShare(entryId: string): void {
  if (!isBrowser()) return;
  const events = readLocalEvents();
  const lastShare = [...events]
    .reverse()
    .find((event) => event.name === QUIET_SHARE_EVENT || event.name === QUIET_SHARE_PNG_EVENT);
  if (!lastShare) return;

  const shareAt = new Date(lastShare.at).getTime();
  const hoursSinceShare = (Date.now() - shareAt) / (1000 * 60 * 60);
  if (hoursSinceShare > 72) return;

  trackRevisitAfterShare(entryId, lastShare.meta?.sourceId);
}

export function buildShareObservationReport(): ShareObservationReport {
  const events = readLocalEvents();
  const shareEvents = events.filter(
    (event) => event.name === QUIET_SHARE_EVENT || event.name === QUIET_SHARE_PNG_EVENT,
  );
  const inviteOpens = events.filter((event) => event.name === INVITE_OPEN_EVENT);
  const creatorCompletions = events.filter(
    (event) => event.name === CREATOR_PREVIEW_COMPLETE_EVENT,
  );
  const revisitAfterShare = events.filter((event) => event.name === REVISIT_AFTER_SHARE_EVENT);

  const copiedThenShared = shareEvents.filter((event) => event.meta?.copiedBefore === "1");

  const sharedCallbacks = shareEvents
    .filter((event) => event.meta?.callbackId)
    .slice(-20)
    .map((event) => ({
      id: event.meta?.callbackId ?? event.meta?.sourceId ?? event.at,
      text: event.meta?.line ?? "",
      source: (event.meta?.source ?? "copied_moment") as QuietShareSource,
      at: event.at,
    }));

  const copiedBeforeShared = copiedThenShared.slice(-12).map((event) => ({
    id: event.meta?.sourceId ?? event.at,
    text: event.meta?.line ?? "",
    at: event.at,
  }));

  return {
    generatedAt: new Date().toISOString(),
    hasData: shareEvents.length > 0 || inviteOpens.length > 0,
    sharedCallbacksCount: shareEvents.filter((event) => event.meta?.callbackId).length,
    sharedRevisitMomentsCount: shareEvents.filter(
      (event) =>
        event.meta?.source === "revisit_payoff" || event.meta?.source === "before_now",
    ).length,
    inviteOpensCount: inviteOpens.length,
    creatorPreviewCompletionsCount: creatorCompletions.length,
    revisitAfterShareCount: revisitAfterShare.length,
    copiedThenSharedCount: copiedThenShared.length,
    sharedCallbacks,
    copiedBeforeShared,
  };
}

export function inviteReturnConversionRate(): number {
  const events = readLocalEvents();
  const invites = events.filter((event) => event.name === INVITE_OPEN_EVENT).length;
  if (invites === 0) return 0;
  const returns = events.filter(
    (event) =>
      event.name === "first_reflection_created" ||
      event.name === "onboarding_completed" ||
      event.name === REVISIT_AFTER_SHARE_EVENT,
  ).length;
  return Math.min(100, Math.round((returns / invites) * 100));
}
