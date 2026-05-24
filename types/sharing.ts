export type QuietShareSource =
  | "revisit_payoff"
  | "before_now"
  | "remembered_later"
  | "roundup"
  | "intention"
  | "copied_moment";

export interface QuietShareCard {
  id: string;
  line: string;
  beforeLabel?: string;
  nowLabel?: string;
  source: QuietShareSource;
  sourceId?: string;
  entryId?: string;
  callbackId?: string;
}

export interface ShareObservationReport {
  generatedAt: string;
  hasData: boolean;
  sharedCallbacksCount: number;
  sharedRevisitMomentsCount: number;
  inviteOpensCount: number;
  creatorPreviewCompletionsCount: number;
  revisitAfterShareCount: number;
  copiedThenSharedCount: number;
  sharedCallbacks: Array<{ id: string; text: string; source: QuietShareSource; at: string }>;
  copiedBeforeShared: Array<{ id: string; text: string; at: string }>;
}

export interface DistributionReadinessReport {
  generatedAt: string;
  hasData: boolean;
  emotionalClarityScore: number;
  creatorPreviewCompletionRate: number;
  inviteReturnConversion: number;
  revisitAfterShareConversion: number;
  mostShareableGroundedLines: Array<{ id: string; text: string; score: number }>;
  cringeRiskLines: Array<{ id: string; text: string; reason: string }>;
  copiedBeforeSharedCallbacks: Array<{ id: string; text: string; at: string }>;
  shareObservation: ShareObservationReport;
}
