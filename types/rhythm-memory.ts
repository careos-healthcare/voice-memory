export type RhythmKind =
  | "after_busy_weeks"
  | "shorter_gap"
  | "longer_calm"
  | "longer_recovery";

export interface RhythmNote {
  id: string;
  text: string;
  kind: RhythmKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastEntryId?: string;
  entryId?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
}

export interface RhythmReport {
  notes: RhythmNote[];
  hasData: boolean;
}

export type RhythmContext = "homepage" | "timeline" | "monthly" | "memory";
