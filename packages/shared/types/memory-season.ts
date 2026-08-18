export type MemorySeasonPeriodType = "calendar_season" | "month";

export type MemorySeasonKind =
  | "lighter_period"
  | "heavier_period"
  | "repeated_theme"
  | "faded_theme"
  | "dominant_focus";

export interface MemorySeasonPeriod {
  id: string;
  slug: string;
  type: MemorySeasonPeriodType;
  label: string;
  startAt: string;
  endAt: string;
  entryIds: string[];
  entryCount: number;
}

export interface MemorySeasonObservation {
  id: string;
  kind: MemorySeasonKind;
  text: string;
  subject?: string;
}

export interface MemorySeason {
  period: MemorySeasonPeriod;
  headline: string;
  observations: MemorySeasonObservation[];
}

export interface MemorySeasonReport {
  seasons: MemorySeason[];
  hasData: boolean;
}

export interface MemorySeasonCopyExample {
  kind: MemorySeasonKind;
  message: string;
  whenShown: string;
}
