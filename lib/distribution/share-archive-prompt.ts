import { ARCHIVE_ATTACHMENT_STRONG_LEVELS } from "@/lib/archive/archive-attachment-copy";
import { readArchiveAttachmentRecords } from "@/lib/archive/archive-attachment";
import {
  latestDistributionMoment,
  readDistributionMoments,
} from "@/lib/distribution/transformation-moments";
import { REFERRAL_SHARE_COOLDOWN_MS, REFERRAL_SHARE_TEXT } from "@/lib/retention/referral-share-prompt";
import { meetsReferralShareEligibility } from "@/lib/retention/referral-share-prompt";
import type { TransformationMomentType } from "@/types/distribution";

export const SHARE_ARCHIVE_PROMPT_LAST_KEY = "voicememory_share_archive_prompt_last";

export const SHARE_ARCHIVE_LABEL = "Share Archive";

export const SHARE_ARCHIVE_TRIGGERS: TransformationMomentType[] = [
  "belief_change",
  "first_strong_attachment",
  "archive_changed_while_away",
  "first_contradiction",
  "first_return_after_archive_change",
];

const TRIGGER_SET = new Set(SHARE_ARCHIVE_TRIGGERS);

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

export function activeShareArchiveTrigger(): TransformationMomentType | null {
  const moments = readDistributionMoments();
  for (let i = moments.length - 1; i >= 0; i--) {
    const row = moments[i]!;
    if (TRIGGER_SET.has(row.type)) return row.type;
  }
  return null;
}

function hasStrongAttachmentMoment(): boolean {
  return readArchiveAttachmentRecords().some((r) =>
    ARCHIVE_ATTACHMENT_STRONG_LEVELS.includes(r.level),
  );
}

export function meetsShareArchiveEligibility(): boolean {
  const trigger = activeShareArchiveTrigger();
  if (trigger) return true;
  if (hasStrongAttachmentMoment()) return true;
  return meetsReferralShareEligibility();
}

export function canShowShareArchivePrompt(now = Date.now()): boolean {
  const store = getStorage();
  if (!store) return false;
  if (!meetsShareArchiveEligibility()) return false;
  const last = store.getItem(SHARE_ARCHIVE_PROMPT_LAST_KEY);
  if (!last) return true;
  return now - new Date(last).getTime() >= REFERRAL_SHARE_COOLDOWN_MS;
}

export function markShareArchivePromptSeen(): void {
  getStorage()?.setItem(SHARE_ARCHIVE_PROMPT_LAST_KEY, new Date().toISOString());
}

export function shareArchiveMessage(): string {
  const moment = latestDistributionMoment(activeShareArchiveTrigger() ?? undefined);
  if (moment?.headline) {
    return `${moment.headline} ${REFERRAL_SHARE_TEXT}`;
  }
  return REFERRAL_SHARE_TEXT;
}

export function clearShareArchivePromptForEval(): void {
  getStorage()?.removeItem(SHARE_ARCHIVE_PROMPT_LAST_KEY);
}
