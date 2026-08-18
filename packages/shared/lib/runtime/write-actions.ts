import {
  trackOpenLoopClosed,
  trackOpenLoopCreated,
  trackOpenLoopEntryReopened,
  trackOpenLoopPromptDismissed,
  trackOpenLoopPromptShown,
  trackOpenLoopReflectionAfterResurface,
  trackOpenLoopResurfacingShown,
  trackOpenLoopReturnPromptEngaged,
  trackOpenLoopReturnPromptShown,
  trackOpenLoopSoftened,
} from "@/lib/open-loops/open-loop-observation";
import {
  closeOpenLoopInStore,
  createOpenLoopInStore,
  dismissOpenLoopPromptInStore,
  maybeLinkReflectionAfterOpenLoopResurface,
  recordOpenLoopMentionedInStore,
  removeOpenLoopsForEntryInStore,
  touchRelatedEntryInStore,
  updateOpenLoopStatusInStore,
} from "@/lib/open-loops/open-loop-storage";
import { hasEntitlement } from "@/lib/entitlement/entitlements";
import {
  enqueueExtractThoughtPatterns,
  enqueueLinkReflectionAfterResurface,
} from "@/lib/runtime/deferred-jobs";
import { dismissClarityPromptInStore } from "@/lib/clarity/clarity-storage";
import { trackClarityEvent, CLARITY_EVENTS } from "@/lib/clarity/clarity-observation";
import { recordOpenLoopReturnPromptShown } from "@/lib/open-loops/open-loop-return-prompt";
import { runWriteAction } from "@/lib/runtime/render-safe";
import type { OpenLoop, OpenLoopStatus } from "@/types/open-loop";

export function writeCreateOpenLoop(input: {
  sourceEntryId: string;
  title: string;
  userNextStep: string;
  anchorPhrases: string[];
  concernLabel?: string;
}): OpenLoop | null {
  if (!hasEntitlement("open_loops")) return null;
  return runWriteAction("writeCreateOpenLoop", () => createOpenLoopInStore(input));
}

export function writeDismissOpenLoopPrompt(
  entryId: string,
  dismissMs?: number,
): void {
  runWriteAction("writeDismissOpenLoopPrompt", () =>
    dismissOpenLoopPromptInStore(entryId, dismissMs),
  );
}

export function writeUpdateOpenLoopStatus(
  openLoopId: string,
  status: OpenLoopStatus,
): OpenLoop | null {
  return runWriteAction("writeUpdateOpenLoopStatus", () =>
    updateOpenLoopStatusInStore(openLoopId, status),
  );
}

export function writeCloseOpenLoop(
  openLoopId: string,
  closureNote?: string,
): OpenLoop | null {
  return runWriteAction("writeCloseOpenLoop", () =>
    closeOpenLoopInStore(openLoopId, closureNote),
  );
}

export function writeTouchOpenLoopRelatedEntry(
  openLoopId: string,
  entryId: string,
): OpenLoop | null {
  return runWriteAction("writeTouchOpenLoopRelatedEntry", () =>
    touchRelatedEntryInStore(openLoopId, entryId),
  );
}

export function writeRecordOpenLoopMentioned(openLoopId: string): void {
  runWriteAction("writeRecordOpenLoopMentioned", () =>
    recordOpenLoopMentionedInStore(openLoopId),
  );
}

export function writeRemoveOpenLoopsForEntry(entryId: string): void {
  runWriteAction("writeRemoveOpenLoopsForEntry", () =>
    removeOpenLoopsForEntryInStore(entryId),
  );
}

export function writeLinkReflectionAfterResurface(entry: {
  id: string;
  createdAt: string;
  transcript: string;
}): void {
  enqueueLinkReflectionAfterResurface(entry);
}

export function writeLinkReflectionAfterResurfaceSync(entry: {
  id: string;
  createdAt: string;
  transcript: string;
}): void {
  runWriteAction("writeLinkReflectionAfterResurfaceSync", () =>
    maybeLinkReflectionAfterOpenLoopResurface(entry),
  );
}

// —— Analytics (write-only, never during render) ——

export function writeTrackOpenLoopPromptShown(entryId: string): void {
  runWriteAction("writeTrackOpenLoopPromptShown", () =>
    trackOpenLoopPromptShown(entryId),
  );
}

export function writeTrackOpenLoopPromptDismissed(entryId: string): void {
  runWriteAction("writeTrackOpenLoopPromptDismissed", () =>
    trackOpenLoopPromptDismissed(entryId),
  );
}

export function writeTrackOpenLoopResurfacingShown(
  openLoopId: string,
  line: string,
): void {
  runWriteAction("writeTrackOpenLoopResurfacingShown", () =>
    trackOpenLoopResurfacingShown(openLoopId, line),
  );
}

export function writeTrackOpenLoopEntryReopened(
  openLoopId: string,
  entryId: string,
): void {
  runWriteAction("writeTrackOpenLoopEntryReopened", () =>
    trackOpenLoopEntryReopened(openLoopId, entryId),
  );
}

export function writeTrackOpenLoopCreated(openLoopId: string, sourceEntryId: string): void {
  runWriteAction("writeTrackOpenLoopCreated", () =>
    trackOpenLoopCreated(openLoopId, sourceEntryId),
  );
}

export function writeTrackOpenLoopSoftened(openLoopId: string): void {
  runWriteAction("writeTrackOpenLoopSoftened", () =>
    trackOpenLoopSoftened(openLoopId),
  );
}

export function writeTrackOpenLoopClosed(openLoopId: string): void {
  runWriteAction("writeTrackOpenLoopClosed", () => trackOpenLoopClosed(openLoopId));
}

export function writeTrackOpenLoopReflectionAfterResurface(
  openLoopId: string,
  entryId: string,
): void {
  runWriteAction("writeTrackOpenLoopReflectionAfterResurface", () =>
    trackOpenLoopReflectionAfterResurface(openLoopId, entryId),
  );
}

export function writeTrackOpenLoopReturnPromptShown(openLoopId: string): void {
  runWriteAction("writeTrackOpenLoopReturnPromptShown", () =>
    trackOpenLoopReturnPromptShown(openLoopId),
  );
}

export function writeTrackOpenLoopReturnPromptEngaged(openLoopId: string): void {
  runWriteAction("writeTrackOpenLoopReturnPromptEngaged", () =>
    trackOpenLoopReturnPromptEngaged(openLoopId),
  );
}

export function writeRecordOpenLoopReturnPromptShown(): void {
  runWriteAction("writeRecordOpenLoopReturnPromptShown", () =>
    recordOpenLoopReturnPromptShown(),
  );
}

export function writeDismissClarityPrompt(entryId: string): void {
  runWriteAction("writeDismissClarityPrompt", () => dismissClarityPromptInStore(entryId));
}

export function writeTrackClarityPromptShown(entryId: string): void {
  runWriteAction("writeTrackClarityPromptShown", () =>
    trackClarityEvent(CLARITY_EVENTS.promptShown, { entryId }),
  );
}

export function writeTrackClarityRecordClicked(entryId: string): void {
  runWriteAction("writeTrackClarityRecordClicked", () =>
    trackClarityEvent(CLARITY_EVENTS.recordClicked, { entryId }),
  );
}

export function writeTrackClarityFollowupSaved(entryId: string, newEntryId: string): void {
  runWriteAction("writeTrackClarityFollowupSaved", () => {
    trackClarityEvent(CLARITY_EVENTS.followupSaved, { entryId, newEntryId });
    trackClarityEvent(CLARITY_EVENTS.reflectionAfterPrompt, { entryId, newEntryId });
  });
}

export function writeTrackClarityAbandoned(entryId: string): void {
  runWriteAction("writeTrackClarityAbandoned", () =>
    trackClarityEvent(CLARITY_EVENTS.abandoned, { entryId }),
  );
}

export function writeTrackThoughtPatternResurfaced(entryId: string, noteId: string): void {
  runWriteAction("writeTrackThoughtPatternResurfaced", () =>
    trackClarityEvent(CLARITY_EVENTS.thoughtPatternResurfaced, { entryId, noteId }),
  );
}

export function writeEnqueueThoughtPatternExtract(payload: {
  entryId: string;
  transcript: string;
}): void {
  runWriteAction("writeEnqueueThoughtPatternExtract", () =>
    enqueueExtractThoughtPatterns(payload),
  );
}
