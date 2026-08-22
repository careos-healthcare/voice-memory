export type ArchiveBeliefAccuracyStatus = "confirmed" | "challenged" | "unclear";

export interface ArchiveBeliefAccuracyRow {
  theoryId: string;
  belief: string;
  status: ArchiveBeliefAccuracyStatus;
  statusLabel: string;
  detail: string | null;
}

export interface ArchiveAccuracyView {
  beliefs: ArchiveBeliefAccuracyRow[];
}
