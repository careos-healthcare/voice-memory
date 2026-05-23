export type TimeMemoryKind =
  | "day_of_week"
  | "time_of_day"
  | "monthly_compare"
  | "seasonal_repeat"
  | "same_day_last_week"
  | "same_day_last_month"
  | "recurring_day"
  | "period_shift"
  | "end_of_week";

export interface TimeMemoryNote {
  id: string;
  text: string;
  kind: TimeMemoryKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastEntryId?: string;
  entryId?: string;
}

export interface TimeMemoryReport {
  notes: TimeMemoryNote[];
  hasData: boolean;
}

export type TimeMemoryContext = "homepage" | "timeline" | "monthly" | "entry";
