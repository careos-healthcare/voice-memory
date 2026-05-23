export type ConversationContinuityKind =
  | "came_back"
  | "left_unresolved"
  | "sounds_like_continuation"
  | "stopped_here"
  | "returned_differently"
  | "thread_changed";

export type ConversationContinuityContext = "homepage" | "entry" | "recorder";

export interface ConversationContinuityNote {
  id: string;
  text: string;
  kind: ConversationContinuityKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastEntryId?: string;
  entryId?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
}

export interface ConversationContinuityReport {
  notes: ConversationContinuityNote[];
  hasData: boolean;
}
