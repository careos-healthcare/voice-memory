export type ResurfacingKind =
  | "topic_return"
  | "phrase_return"
  | "entity_return"
  | "quieter_return"
  | "heavier_return"
  | "unresolved_loop"
  | "similar_to_today"
  | "last_appeared";

export interface ResurfacingNote {
  id: string;
  text: string;
  kind: ResurfacingKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastEntryId?: string;
  entryId: string;
}

export interface ResurfacingReport {
  notes: ResurfacingNote[];
  hasData: boolean;
}
