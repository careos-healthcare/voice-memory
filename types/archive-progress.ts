import type { ArchiveMaturityStage } from "@/types/archive-maturity";

export interface ArchiveMaturityEngineInput {
  reflectionCount: number;
  beliefCount: number;
  beliefChanges: number;
  reputationScore: number;
  timelineAgeDays: number;
}

export interface ArchiveProgressView {
  score: number;
  stage: ArchiveMaturityStage;
  stageLabel: string;
  headline: string;
  nextMilestoneLabel: string;
  nextMilestonePercent: number;
}
