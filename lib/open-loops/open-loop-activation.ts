import { isWithinFreshEntryWindow, isFreshEntryQuietMode } from "@/lib/refinement/entry-quiet-state";
import {
  detectUnresolvedThread,
  hasUnresolvedThreadLanguage,
} from "@/lib/open-loops/unresolved-signals";
import { logOpenLoopActivationDebug } from "@/lib/open-loops/open-loop-activation-debug";
import {
  auditOpenLoopActivation,
  resolveOpenLoopActivationSuppression,
} from "@/lib/open-loops/open-loop-activation-audit";
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
  options?: { isRevisit?: boolean; heavyReady?: boolean | null },
): OpenLoopActivationContext {
  const transcript = entry.transcript?.trim() ?? "";
  const signal = transcript ? detectUnresolvedThread(transcript) : null;
  const isFresh = isFreshEntryQuietMode(entry.id, entry.createdAt);
  const isRevisit = Boolean(options?.isRevisit);
  const inFreshWindow = isWithinFreshEntryWindow(entry.createdAt);
  const suppression = resolveOpenLoopActivationSuppression(entry);
  const showPrompt = suppression === null;

  const context: OpenLoopActivationContext = {
    showPrompt,
    prominent: showPrompt && (isFresh || isRevisit || inFreshWindow),
    isFresh,
    isRevisit,
    signal,
  };

  logOpenLoopActivationDebug("resolveOpenLoopActivation", {
    entryId: entry.id,
    unresolvedDetected: hasUnresolvedThreadLanguage(transcript),
    matchedPhrases: signal?.anchorPhrases ?? [],
    matchedLabels: signal?.matchedLabels ?? [],
    existingLoopFound: suppression === "active_loop_for_entry",
    dismissedRecently: suppression === "dismissed_recently",
    freshEntryWindow: inFreshWindow,
    revisitMode: isRevisit,
    isFreshQuiet: isFresh,
    heavyReady: options?.heavyReady ?? null,
    activationSuppressedReason: suppression,
    showPrompt: context.showPrompt,
  });

  return context;
}

export { auditOpenLoopActivation, resolveOpenLoopActivationSuppression };
export type {
  OpenLoopActivationAudit,
  OpenLoopActivationSuppressionReason,
} from "@/lib/open-loops/open-loop-activation-audit";

export const OPEN_LOOP_PROMPT_DISMISS_MS = PROMPT_DISMISS_MS;
