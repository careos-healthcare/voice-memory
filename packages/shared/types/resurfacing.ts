export type ResurfacingKind =
  | "topic_silence"
  | "person_silence"
  | "phrase_return"
  | "loop_return"
  | "calmer_return"
  | "heavier_return"
  | "direct_return"
  | "vague_return";

export interface ResurfacingNote {
  id: string;
  text: string;
  kind: ResurfacingKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  pastEntryId?: string;
  entryId: string;
}

export interface ResurfacingReport {
  notes: ResurfacingNote[];
  hasData: boolean;
}
