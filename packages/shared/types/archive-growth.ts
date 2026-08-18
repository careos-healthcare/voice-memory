export type ArchiveGrowthKind =
  | "connecting_older"
  | "read_differently"
  | "more_familiar"
  | "more_continuity"
  | "starting_to_relate";

export interface ArchiveGrowthNote {
  id: string;
  text: string;
  kind: ArchiveGrowthKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastEntryId?: string;
  entryId?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
}

export interface ArchiveGrowthReport {
  notes: ArchiveGrowthNote[];
  hasData: boolean;
}

export type ArchiveGrowthContext = "homepage" | "monthly" | "memory";
