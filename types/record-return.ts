import type { FollowupSource } from "@/types/followup-prompt";

export type RecordReturnSource = FollowupSource | "primary_callback" | "open_loop";

/** Context for one-tap record-again after a callback or open loop resurfaces. */
export interface RecordReturnContext {
  id: string;
  anchorQuote: string;
  noteId: string;
  source: RecordReturnSource;
  openLoopId?: string;
  pastEntryId?: string;
  promptId?: string;
}
