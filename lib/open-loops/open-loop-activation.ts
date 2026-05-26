import { isWithinFreshEntryWindow, isFreshEntryQuietMode } from "@/lib/refinement/entry-quiet-state";
import {
  hasUnresolvedThreadLanguage,
  detectUnresolvedThread,
} from "@/lib/open-loops/unresolved-signals";
import { hasActiveOpenLoopForEntry, isOpenLoopPromptDismissed } from "@/lib/open-loops/open-loop-storage";
import type { JournalEntry } from "@/types/journal";

const PROMPT_DISMISS_MS = 48 * 60 * 60 * 1000;

export interface OpenLoopActivationContext {
  showPrompt: boolean;
  prominent: boolean;
  isFresh: boolean;
  isRevisit: boolean;
  signal: ReturnType<typeof detectUnresolvedThread>;
}

/** When to surface the keep-thread-open prompt — no coaching, user-owned. */
export function resolveOpenLoopActivation(
  entry: JournalEntry,
  options?: { isRevisit?: boolean },
): OpenLoopActivationContext {
  const transcript = entry.transcript?.trim() ?? "";
  const signal = transcript ? detectUnresolvedThread(transcript) : null;
  const isFresh = isFreshEntryQuietMode(entry.id, entry.createdAt);
  const isRevisit = Boolean(options?.isRevisit);
  const inFreshWindow = isWithinFreshEntryWindow(entry.createdAt);

  const hasUnresolved = Boolean(signal) || hasUnresolvedThreadLanguage(transcript);
  const dismissed = isOpenLoopPromptDismissed(entry.id);
  const hasLoop = hasActiveOpenLoopForEntry(entry.id);

  const showPrompt =
    hasUnresolved &&
    !hasLoop &&
    !dismissed &&
    (isFresh || isRevisit || inFreshWindow);

  const prominent = showPrompt && (isFresh || isRevisit || inFreshWindow);

  return {
    showPrompt,
    prominent,
    isFresh,
    isRevisit,
    signal,
  };
}

export const OPEN_LOOP_PROMPT_DISMISS_MS = PROMPT_DISMISS_MS;
