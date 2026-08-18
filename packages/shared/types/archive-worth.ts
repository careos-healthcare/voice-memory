export type ArchiveWorthCtaId = "protect_archive" | "export_archive" | "pro_continuity";

export interface ArchiveWorthSnapshot {
  headline: string;
  summaryLine: string;
  reflectionCount: number;
  daysCovered: number | null;
  workingBeliefs: number;
  beliefsTracked: number;
  beliefChangesRecorded: number;
  evidenceQuotesStored: number;
  firstReflectionDateLabel: string | null;
  strongestRememberedBelief: string | null;
  suggestedCtas: ArchiveWorthCtaId[];
}
