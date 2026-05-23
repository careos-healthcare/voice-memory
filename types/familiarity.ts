export type FamiliarityKind =
  | "more_settled_than_usual"
  | "more_direct_than_usual"
  | "quicker_return"
  | "longer_circle_usual"
  | "unusual_tension"
  | "unusual_loop";

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
