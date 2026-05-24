import { storeFollowupPrompt } from "@/lib/conversation/followup-prompts";
import {
  storeContinuationMeta,
  trackContinuationStarted,
} from "@/lib/conversation/continuation-loops";
import { upsertIntentionFromRoundup } from "@/lib/intentions/long-term-intentions";
import { trackLocalEvent } from "@/lib/local-analytics";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { LongTermIntention } from "@/types/long-term-intentions";
import type { RoundupContinuationItem } from "@/types/reflective-roundup";

const SAVED_ROUNDUP_ITEMS_KEY = "voicememory_roundup_saved_items";

export const ROUNDUP_CONTINUE_CLICKED = "roundup_continue_clicked";
export const ROUNDUP_INTENTION_SAVED = "roundup_intention_saved";
export const ROUNDUP_ITEM_REVISITED = "roundup_item_revisited";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readSavedRoundupItems(): string[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(SAVED_ROUNDUP_ITEMS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as string[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeSavedRoundupItems(ids: string[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(SAVED_ROUNDUP_ITEMS_KEY, JSON.stringify(ids.slice(-120)));
}

export function isRoundupItemSaved(itemId: string): boolean {
  return readSavedRoundupItems().includes(itemId);
}

export function trackRoundupContinueClicked(item: RoundupContinuationItem, periodSlug?: string): void {
  trackLocalEvent(ROUNDUP_CONTINUE_CLICKED, {
    itemId: item.id,
    kind: item.kind,
    periodSlug: periodSlug ?? "",
  });
}

export function trackRoundupIntentionSaved(
  item: RoundupContinuationItem,
  intentionId: string,
  periodSlug?: string,
): void {
  trackLocalEvent(ROUNDUP_INTENTION_SAVED, {
    itemId: item.id,
    intentionId,
    kind: item.kind,
    periodSlug: periodSlug ?? "",
  });
}

export function trackRoundupItemRevisited(
  item: RoundupContinuationItem,
  entryId: string,
  periodSlug?: string,
): void {
  trackLocalEvent(ROUNDUP_ITEM_REVISITED, {
    itemId: item.id,
    entryId,
    kind: item.kind,
    periodSlug: periodSlug ?? "",
  });
}

export function buildRoundupFollowupPrompt(item: RoundupContinuationItem): FollowupPrompt {
  const text = item.text.trim().replace(/[.…]+$/, "");
  return {
    id: `followup-roundup-${item.id}`,
    text: text.endsWith("?") ? text : `${text}…`,
    source: "continuation",
    noteId: `roundup-${item.id}`,
    noteText: item.text,
    strength: 70,
  };
}

/** Send a roundup line into the existing recorder continuation flow. */
export function continueRoundupThought(
  item: RoundupContinuationItem,
  periodSlug?: string,
): FollowupPrompt {
  const prompt = buildRoundupFollowupPrompt(item);
  storeFollowupPrompt(prompt);
  storeContinuationMeta(prompt.id, prompt.noteId);
  trackContinuationStarted(prompt.id, prompt.noteId);
  trackRoundupContinueClicked(item, periodSlug);
  return prompt;
}

/** Save or update a long-term intention from a roundup line. */
export function saveRoundupToReturnTo(
  item: RoundupContinuationItem,
  periodSlug?: string,
): LongTermIntention {
  const intention = upsertIntentionFromRoundup({
    text: item.text,
    entryId: item.entryId,
  });

  const saved = readSavedRoundupItems();
  if (!saved.includes(item.id)) {
    writeSavedRoundupItems([...saved, item.id]);
  }

  trackRoundupIntentionSaved(item, intention.id, periodSlug);
  return intention;
}

export const ROUNDUP_SAVED_COPY = "This is now something you can come back to.";
