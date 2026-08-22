import type { ReflectiveRoundupSignal } from "@/types/reflective-roundup";

export type RoundupReturnWindow = "24h" | "7d";

export interface RoundupLineMetricRow {
  lineKey: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  pauses: number;
  copies: number;
  bookmarks: number;
  continues: number;
  intentionsSaved: number;
  relatedEntryOpens: number;
  followupsRecorded: number;
  continuationScore: number;
  ignoreRatio: number;
  dead: boolean;
}

export interface RoundupPauseNoActionRow {
  lineKey: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  pauseCount: number;
  dwellMs: number;
}

export interface RoundupObservationReport {
  generatedAt: string;
  hasData: boolean;
  roundupOpens: number;
  instantAbandons: number;
  returns24h: number;
  returns7d: number;
  continuationConversion: string;
  topContinuationLines: RoundupLineMetricRow[];
  deadRoundupLines: RoundupLineMetricRow[];
  revisitDrivingLines: RoundupLineMetricRow[];
  copiedLines: RoundupLineMetricRow[];
  bookmarkDrivingLines: RoundupLineMetricRow[];
  pauseWithNoAction: RoundupPauseNoActionRow[];
}
