import { recordRecordingAfterCallback } from "@/lib/callback-interaction-signals";
import { trackFollowupRecordingStarted } from "@/lib/retention/retention-loops";
import { trackLocalEvent } from "@/lib/local-analytics";
import { markFollowupBoost } from "@/lib/refinement/emotional-timing";
import { trackFollowUpAfterCallback } from "@/lib/retention/pause-moments";
import { trackRevisitRhythmFollowupIfActive } from "@/lib/refinement/revisit-rhythm";
import { observeCallbackOpened } from "@/lib/revisit/callback-learning";
import { buildDirectRecordHref } from "@/lib/capture/direct-record";
import { recordResurfacingOpened } from "@/lib/resurfacing/resurfacing-fatigue";
import { observeResurfacingModeOpened } from "@/lib/resurfacing/resurfacing-mode-observation";
import { markReturnRecorderOpened } from "@/lib/reflection/reflection-friction-report";
import { storeRecordReturnContext } from "@/lib/reflection/record-return";
import { recordFollowupContinued } from "@/lib/callback-interaction-signals";
import { trackContinuationStarted } from "@/lib/conversation/continuation-loops";
import type { RecordReturnContext } from "@/types/record-return";

function sourceForReturn(
  context: RecordReturnContext,
): "resurfacing" | "open_loop" | "return" {
  if (context.source === "open_loop") return "open_loop";
  if (context.source === "primary_callback" || context.source === "resurfacing") {
    return "resurfacing";
  }
  return "return";
}

/** Href for direct `/record` — homepage not required. */
export function hrefForRecordReturn(context: RecordReturnContext): string {
  return buildDirectRecordHref({
    source: sourceForReturn(context),
    quote: context.anchorQuote,
    loopId: context.openLoopId,
    entryId: context.pastEntryId,
    autostart: true,
  });
}

/** One-tap path into the recorder with return context preserved. */
export function startRecordReturnFlow(context: RecordReturnContext): string {
  storeRecordReturnContext(context);
  const href = hrefForRecordReturn(context);
  recordResurfacingOpened(context.noteId);
  observeResurfacingModeOpened(
    { id: context.noteId, pastEntryId: context.pastEntryId, text: context.anchorQuote },
    undefined,
    context.returnMode,
  );
  markReturnRecorderOpened();
  trackLocalEvent("record_return_opened", {
    noteId: context.noteId,
    source: context.source,
  });
  observeCallbackOpened({ id: context.noteId, pastEntryId: context.pastEntryId });
  recordFollowupContinued(context.noteId);
  trackContinuationStarted(context.promptId ?? context.id, context.noteId);
  trackFollowupRecordingStarted(context.noteId, context.promptId ?? context.id);
  trackFollowUpAfterCallback(context.noteId, context.promptId ?? context.id);
  markFollowupBoost();
  trackRevisitRhythmFollowupIfActive(context.noteId, context.promptId ?? context.id);
  recordRecordingAfterCallback(context.noteId);
  return href;
}
