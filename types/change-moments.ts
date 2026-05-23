export type ChangeMomentKind =
  | "recovery_after_topic"
  | "calmer_return"
  | "shorter_spiral"
  | "less_hedging"
  | "more_direct"
  | "less_charged"
  | "phrase_disappeared"
  | "future_forward"
  | "concern_absent"
  | "you_sound_different";

export interface ChangeMomentNote {
  id: string;
  text: string;
  kind: ChangeMomentKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  pastEntryId?: string;
  entryId?: string;
}

export interface ChangeMomentsReport {
  notes: ChangeMomentNote[];
  hasData: boolean;
}

export type ChangeMomentsContext = "entry" | "timeline" | "monthly" | "memory";
