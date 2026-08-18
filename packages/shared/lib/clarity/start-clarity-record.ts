import { trackClarityEvent, CLARITY_EVENTS } from "@/lib/clarity/clarity-observation";
import {
  buildClarityRecordContext,
  storeClarityRecordContext,
} from "@/lib/clarity/clarity-record";
import { writeTrackClarityRecordClicked } from "@/lib/runtime/write-actions";

export function startClarityRecordFlow(entryId: string, anchorSnippet: string): void {
  const context = buildClarityRecordContext({ entryId, anchorSnippet });
  storeClarityRecordContext(context);
  writeTrackClarityRecordClicked(entryId);
  trackClarityEvent(CLARITY_EVENTS.recordClicked, { entryId });
}
