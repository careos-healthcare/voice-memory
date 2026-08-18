import { isWithinFreshEntryWindow, isFreshEntryQuietMode } from "@/lib/refinement/entry-quiet-state";
import { getCachedUnresolvedThread } from "@/lib/open-loops/unresolved-cache";
import {
  hasUnresolvedThreadLanguage,
  unresolvedDetectionScore,
} from "@/lib/open-loops/unresolved-signals";
import { logOpenLoopActivationDebug } from "@/lib/open-loops/open-loop-activation-debug";
import {
  readHasActiveOpenLoopForEntry,
  readIsOpenLoopPromptDismissed,
} from "@/lib/open-loops/open-loop-storage";
import type { JournalEntry } from "@/types/journal";
import type { UnresolvedThreadSignal } from "@/lib/open-loops/unresolved-detect-core";

export type OpenLoopActivationSuppressionReason =
  | "no_transcript"
  | "no_unresolved_language"
  | "active_loop_for_entry"
  | "dismissed_recently"
  | null;

export interface OpenLoopActivationAudit {
  entryId: string;
  transcriptLength: number;
  unresolvedDetected: boolean;
  unresolvedScore: number;
  matchedSignals: string[];
  matchedLabels: string[];
  signal: UnresolvedThreadSignal | null;
  existingLoopFound: boolean;
  dismissedRecently: boolean;
  freshEntryWindow: boolean;
  isFreshQuiet: boolean;
  revisitMode: boolean;
  heavyReady: boolean | null;
  showPrompt: boolean;
  prominent: boolean;
  activationSuppressedReason: OpenLoopActivationSuppressionReason;
}

export function resolveOpenLoopActivationSuppression(
  entry: JournalEntry,
  overrides?: {
    dismissed?: boolean;
    hasLoop?: boolean;
  },
): OpenLoopActivationSuppressionReason {
  const transcript = entry.transcript?.trim() ?? "";
  if (!transcript) return "no_transcript";

  const unresolvedDetected = hasUnresolvedThreadLanguage(transcript);
  if (!unresolvedDetected) return "no_unresolved_language";

  const hasLoop =
    overrides?.hasLoop ?? readHasActiveOpenLoopForEntry(entry.id);
  if (hasLoop) return "active_loop_for_entry";

  const dismissed =
    overrides?.dismissed ?? readIsOpenLoopPromptDismissed(entry.id);
  if (dismissed) return "dismissed_recently";

  return null;
}

export function auditOpenLoopActivation(
  entry: JournalEntry,
  options?: {
    isRevisit?: boolean;
    heavyReady?: boolean | null;
    dismissed?: boolean;
    hasLoop?: boolean;
    logSource?: string;
  },
): OpenLoopActivationAudit {
  const transcript = entry.transcript?.trim() ?? "";
  const signal = transcript ? getCachedUnresolvedThread(transcript) : null;
  const unresolvedDetected = hasUnresolvedThreadLanguage(transcript);
  const suppression = resolveOpenLoopActivationSuppression(entry, {
    dismissed: options?.dismissed,
    hasLoop: options?.hasLoop,
  });

  const isFreshQuiet = isFreshEntryQuietMode(entry.id, entry.createdAt);
  const freshEntryWindow = isWithinFreshEntryWindow(entry.createdAt);
  const revisitMode = Boolean(options?.isRevisit);
  const existingLoopFound =
    options?.hasLoop ?? readHasActiveOpenLoopForEntry(entry.id);
  const dismissedRecently =
    options?.dismissed ?? readIsOpenLoopPromptDismissed(entry.id);

  const showPrompt = suppression === null;
  const prominent =
    showPrompt && (isFreshQuiet || revisitMode || freshEntryWindow);

  const audit: OpenLoopActivationAudit = {
    entryId: entry.id,
    transcriptLength: transcript.length,
    unresolvedDetected,
    unresolvedScore: unresolvedDetectionScore(transcript),
    matchedSignals: signal?.anchorPhrases ?? [],
    matchedLabels: signal?.matchedLabels ?? [],
    signal,
    existingLoopFound,
    dismissedRecently,
    freshEntryWindow,
    isFreshQuiet,
    revisitMode,
    heavyReady: options?.heavyReady ?? null,
    showPrompt,
    prominent,
    activationSuppressedReason: suppression,
  };

  if (options?.logSource) {
    logOpenLoopActivationDebug(options.logSource, { ...audit });
  }

  return audit;
}
