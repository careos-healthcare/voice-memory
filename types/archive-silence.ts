export type ArchiveSilenceKind =
  | "belief_evidence_gap"
  | "life_area_absent"
  | "pattern_fading";

export interface ArchiveSilenceSignal {
  id: string;
  kind: ArchiveSilenceKind;
  text: string;
}

export interface ArchiveSilenceView {
  signals: ArchiveSilenceSignal[];
}
