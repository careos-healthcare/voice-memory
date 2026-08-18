export type FirstWeekFunnelStage =
  | "first_visit"
  | "onboarding_completed"
  | "onboarding_skipped"
  | "recorder_viewed"
  | "first_reflection_saved"
  | "second_reflection_saved"
  | "first_resurfacing_candidate"
  | "first_magic_moment"
  | "return_within_24h"
  | "return_within_7d";

/** Server-ready payload — same shape locally and for future sync. */
export interface FirstWeekFunnelEventPayload {
  schemaVersion: "1";
  stage: FirstWeekFunnelStage;
  at: string;
  meta?: Record<string, string>;
}

export interface FirstWeekFunnelStageRow {
  stage: FirstWeekFunnelStage;
  label: string;
  at: string | null;
  reached: boolean;
}

export interface FirstWeekFunnelConversionRow {
  from: FirstWeekFunnelStage;
  to: FirstWeekFunnelStage;
  rate: number;
  reached: boolean;
}

export interface FirstWeekFunnelMetrics {
  currentStage: FirstWeekFunnelStage | null;
  deepestLinearStage: FirstWeekFunnelStage | null;
  stagesReached: number;
  msFromFirstVisitToFirstReflection: number | null;
  msFromFirstReflectionToResurfacing: number | null;
  msFromFirstReflectionToMagicMoment: number | null;
  msFromFirstVisitToReturn24h: number | null;
  msFromFirstVisitToReturn7d: number | null;
}

export interface FirstWeekFunnelDebugReport {
  generatedAt: string;
  hasData: boolean;
  stages: FirstWeekFunnelStageRow[];
  conversions: FirstWeekFunnelConversionRow[];
  metrics: FirstWeekFunnelMetrics;
  recentEvents: FirstWeekFunnelEventPayload[];
}
