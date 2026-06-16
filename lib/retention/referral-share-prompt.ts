import { ARCHIVE_ATTACHMENT_STRONG_LEVELS } from "@/lib/archive/archive-attachment-copy";
import { readArchiveAttachmentRecords } from "@/lib/archive/archive-attachment";
import { readBeliefRecallRecords } from "@/lib/retention/belief-recall";
import { readOrganicReferralRecords } from "@/lib/retention/organic-referral";
import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { readAllTheoryFeedback } from "@/lib/theories/theory-feedback";
import { ACTIVATION_METRIC_EVENTS } from "@/lib/product/activation-metrics";
import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";

export const REFERRAL_SHARE_PROMPT_LAST_KEY = "voicememory_referral_share_prompt_last";
export const REFERRAL_SHARE_COOLDOWN_MS = 21 * 24 * 60 * 60 * 1000;

export const REFERRAL_SHARE_TEXT =
  "ArchiveMe builds an evidence trail of what keeps repeating in your life.";

export const REFERRAL_SHARE_EVENT_NAMES = {
  seen: "referral_share_prompt_seen" as const,
  clicked: "referral_share_clicked" as const,
};

const STRONG_BLIND = new Set(["surprising", "uncomfortably_accurate"]);
const STRONG_THEORY = new Set(["surprising"]);

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

function hasStrongReaction(): boolean {
  if (readAllBlindSpotFeedback().some((f) => STRONG_BLIND.has(f.reaction))) return true;
  if (readAllTheoryFeedback().some((f) => STRONG_THEORY.has(f.reaction))) return true;
  return readLocalEvents().some(
    (e) => e.name === ACTIVATION_METRIC_EVENTS.strongInsightReaction,
  );
}

function hasHighAttachment(): boolean {
  return readArchiveAttachmentRecords().some((r) =>
    ARCHIVE_ATTACHMENT_STRONG_LEVELS.includes(r.level),
  );
}

function hasBeliefRemembered(): boolean {
  return readBeliefRecallRecords().some(
    (r) => r.level === "yes_clearly" || r.level === "vaguely",
  );
}

function hasOrganicReferralSignal(): boolean {
  return readOrganicReferralRecords().some(
    (r) => r.status === "yes" || r.status === "thought_about_it",
  );
}

export function meetsReferralShareEligibility(): boolean {
  let signals = 0;
  if (hasStrongReaction()) signals += 1;
  if (hasHighAttachment()) signals += 1;
  if (hasBeliefRemembered()) signals += 1;
  if (hasOrganicReferralSignal()) signals += 1;
  return signals >= 1;
}

export function canShowReferralSharePrompt(now = Date.now()): boolean {
  const store = getStorage();
  if (!store) return false;
  if (!meetsReferralShareEligibility()) return false;
  const last = store.getItem(REFERRAL_SHARE_PROMPT_LAST_KEY);
  if (!last) return true;
  return now - new Date(last).getTime() >= REFERRAL_SHARE_COOLDOWN_MS;
}

export function markReferralSharePromptSeen(): void {
  getStorage()?.setItem(REFERRAL_SHARE_PROMPT_LAST_KEY, new Date().toISOString());
  trackLocalEvent(REFERRAL_SHARE_EVENT_NAMES.seen, {});
}

export function trackReferralShareClicked(): void {
  trackLocalEvent(REFERRAL_SHARE_EVENT_NAMES.clicked, {});
  markReferralSharePromptSeen();
}

export function dismissReferralSharePrompt(): void {
  markReferralSharePromptSeen();
}

export function clearReferralShareForEval(): void {
  getStorage()?.removeItem(REFERRAL_SHARE_PROMPT_LAST_KEY);
}
