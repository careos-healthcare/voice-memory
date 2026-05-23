export type FamiliarityResurfacingKind =
  | "sound_different"
  | "earlier_loop"
  | "first_calmer_topic"
  | "before_direct_naming"
  | "before_major_shift"
  | "monthly_contrast"
  | "emotionally_similar"
  | "emotionally_opposite";

export interface FamiliarityResurfacingNote {
  id: string;
  text: string;
  kind: FamiliarityResurfacingKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  pastEntryId?: string;
  entryId: string;
}

export interface FamiliarityResurfacingReport {
  notes: FamiliarityResurfacingNote[];
  hasData: boolean;
}

export type FamiliarityResurfacingContext =
  | "homepage"
  | "entry"
  | "timeline"
  | "monthly"
  | "memory";
