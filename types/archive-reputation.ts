export type ArchiveReputationLevel =
  | "low"
  | "developing"
  | "moderate"
  | "high"
  | "very_high";

export type ArchiveReputationView = {
  level: ArchiveReputationLevel;
  supportingReflections: number;
  lifeAreas: number;
  contradictionsSurvived: number;
  daysTracked: number;
  beliefChangesObserved: number;
  accuracySignals: number;
  summary: string;
  /** Internal 0–100 for meter display only — not shown as a user-facing score label. */
  meterFill: number;
};
