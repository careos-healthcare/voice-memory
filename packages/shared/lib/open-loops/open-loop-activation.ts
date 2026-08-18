import { isWithinFreshEntryWindow, isFreshEntryQuietMode } from "@/lib/refinement/entry-quiet-state";
import { getCachedUnresolvedThread } from "@/lib/open-loops/unresolved-cache";
import { hasUnresolvedThreadLanguage } from "@/lib/open-loops/unresolved-signals";
import { logOpenLoopActivationDebug } from "@/lib/open-loops/open-loop-activation-debug";
import {
  auditOpenLoopActivation,
  resolveOpenLoopActivationSuppression,
} from "@/lib/open-loops/open-loop-activation-audit";
import {
  recordFunctionInvocation,
  transcriptCacheKey,
} from "@/lib/open-loops/open-loop-performance";
import type { JournalEntry } from "@/types/journal";

const PROMPT_DISMISS_MS = 48 * 60 * 60 * 1000;

const activationByTranscriptKey = new Map<
  string,
  {
    showPrompt: boolean;
    prominent: boolean;
    isFresh: boolean;
    isRevisit: boolean;
    signal: ReturnType<typeof getCachedUnresolvedThread>;
  }
>();

export interface OpenLoopActivationContext {
  showPrompt: boolean;
  prominent: boolean;
  isFresh: boolean;
  isRevisit: boolean;
  signal: ReturnType<typeof getCachedUnresolvedThread>;
}

/** When to surface the keep-thread-open prompt — no coaching, user-owned. */
export function resolveOpenLoopActivation(
  entry: JournalEntry,
  options?: { isRevisit?: boolean; heavyReady?: boolean | null },
): OpenLoopActivationContext {
  recordFunctionInvocation("resolveOpenLoopActivation");

  const transcript = entry.transcript?.trim() ?? "";
  const cacheKey = `${entry.id}:${transcriptCacheKey(transcript)}:${options?.isRevisit ? "1" : "0"}`;
  const cached = activationByTranscriptKey.get(cacheKey);
  if (cached) return cached;

  const signal = transcript ? getCachedUnresolvedThread(transcript) : null;
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

  activationByTranscriptKey.set(cacheKey, context);

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

export function resetOpenLoopActivationCache(): void {
  activationByTranscriptKey.clear();
}

export { auditOpenLoopActivation, resolveOpenLoopActivationSuppression };
export type {
  OpenLoopActivationAudit,
  OpenLoopActivationSuppressionReason,
} from "@/lib/open-loops/open-loop-activation-audit";

export const OPEN_LOOP_PROMPT_DISMISS_MS = PROMPT_DISMISS_MS;
