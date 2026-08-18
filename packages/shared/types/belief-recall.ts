export const BELIEF_RECALL_LEVEL_IDS = ["yes_clearly", "vaguely", "no"] as const;

export type BeliefRecallLevelId = (typeof BELIEF_RECALL_LEVEL_IDS)[number];

export type BeliefRecallVerdict = "strong" | "weak" | "mixed" | "insufficient_data";

export interface BeliefRecallRecord {
  id: string;
  level: BeliefRecallLevelId;
  answeredAt: string;
  theoryId: string;
  note?: string;
  followUpAnsweredAt?: string;
}

export interface BeliefRecallReport {
  criticalQuestion: string;
  criticalAnswer: string;
  verdict: BeliefRecallVerdict;
  yesClearlyRate: number | null;
  rememberedRate: number | null;
  totalResponses: number;
  recentRecords: BeliefRecallRecord[];
}
