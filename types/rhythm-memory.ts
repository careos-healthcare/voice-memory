export type RhythmKind =
  | "after_busy_weeks"
  | "shorter_gap"
  | "longer_calm"
  | "end_of_week_return"
  | "weekly_loop"
  | "longer_recovery"
  | "tension_interval"
  | "rhythm_disruption"
  | "late_night_weekend";

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
