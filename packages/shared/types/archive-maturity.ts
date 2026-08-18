export type ArchiveMaturityStage =
  | "starting"
  | "building_evidence"
  | "beliefs_forming"
  | "beliefs_changing"
  | "mature_archive";

export interface ArchiveMaturityView {
  stage: ArchiveMaturityStage;
  stageLabel: string;
  percent: number;
  tagline: string;
}
