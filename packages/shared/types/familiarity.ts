export type FamiliarityKind =
  | "more_settled_than_usual"
  | "more_direct_than_usual"
  | "quicker_return"
  | "stopped_circling"
  | "slower_return"
  | "heavier_before";

export interface FamiliarityNote {
  id: string;
  text: string;
  kind: FamiliarityKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastEntryId?: string;
  entryId?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
}

export interface FamiliarityReport {
  notes: FamiliarityNote[];
  hasData: boolean;
}

export type FamiliarityContext = "homepage" | "entry" | "timeline" | "monthly" | "memory";
