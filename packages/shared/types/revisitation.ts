export type RevisitationKind =
  | "related_older"
  | "first_topic"
  | "before_quieter"
  | "reads_differently"
  | "loop_return"
  | "worth_revisit";

export interface RevisitationNote {
  id: string;
  text: string;
  kind: RevisitationKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastEntryId?: string;
  entryId?: string;
}

export interface RevisitationReport {
  notes: RevisitationNote[];
  hasData: boolean;
}

export type RevisitationContext = "homepage" | "entry" | "timeline" | "monthly" | "memory";
