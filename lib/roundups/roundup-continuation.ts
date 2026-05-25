import { storeFollowupPrompt } from "@/lib/conversation/followup-prompts";
import {
  storeContinuationMeta,
  trackContinuationStarted,
} from "@/lib/conversation/continuation-loops";
import { upsertIntentionFromRoundup } from "@/lib/intentions/long-term-intentions";
import {
  trackRoundupContinueClicked as trackRoundupContinueObservation,
  trackRoundupIntentionSaved as trackRoundupIntentionSavedObservation,
  trackRoundupItemRevisited as trackRoundupItemRevisitedObservation,
} from "@/lib/roundups/roundup-observation";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { LongTermIntention } from "@/types/long-term-intentions";
import type { RoundupContinuationItem, ReflectiveRoundupSignal } from "@/types/reflective-roundup";

const SAVED_ROUNDUP_ITEMS_KEY = "voicememory_roundup_saved_items";

export {
  ROUNDUP_CONTINUE_CLICKED,
  ROUNDUP_INTENTION_SAVED,
  ROUNDUP_ITEM_REVISITED,
} from "@/lib/roundups/roundup-observation";

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

function signalForItem(item: RoundupContinuationItem): ReflectiveRoundupSignal {
  if (item.kind === "key_piece") return "revisited";
  return "returned";
}

export function trackRoundupContinueClicked(item: RoundupContinuationItem, periodSlug?: string): void {
  trackRoundupContinueObservation({
    itemId: item.id,
    text: item.text,
    signal: signalForItem(item),
    periodSlug,
    kind: item.kind,
  });
}

export function trackRoundupIntentionSaved(
  item: RoundupContinuationItem,
  intentionId: string,
  periodSlug?: string,
): void {
  trackRoundupIntentionSavedObservation({
    itemId: item.id,
    text: item.text,
    signal: signalForItem(item),
    periodSlug,
    intentionId,
    kind: item.kind,
  });
}

export function trackRoundupItemRevisited(
  item: RoundupContinuationItem,
  entryId: string,
  periodSlug?: string,
): void {
  trackRoundupItemRevisitedObservation({
    itemId: item.id,
    text: item.text,
    signal: signalForItem(item),
    periodSlug,
    entryId,
    kind: item.kind,
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
