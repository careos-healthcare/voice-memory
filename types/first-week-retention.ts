export type FirstWeekMilestoneId =
  | "first_reflection"
  | "second_reflection"
  | "first_revisit"
  | "first_emotional_callback"
  | "first_photo_revisit"
  | "first_territory_emergence";

export type FirstWeekTimingAction =
  | "surface_revisit"
  | "stay_silent"
  | "invite_reflection";

export interface FirstWeekMilestone {
  id: FirstWeekMilestoneId;
  reachedAt: string | null;
  evidence: string;
}

export interface FirstWeekTimingRecommendation {
  action: FirstWeekTimingAction;
  reason: string;
  priority: number;
}

export type ArchiveAttachmentLevel = "weak" | "emerging" | "strong";

export type GentleReturnPromptId =
  | "week_disappearing"
  | "earlier_this_week"
  | "continuity_building"
  | "meaningful_revisit";

export interface GentleReturnPromptOffer {
  id: GentleReturnPromptId;
  text: string;
  href?: string;
  entryId?: string;
}

export interface ArchiveValueMomentOffer {
  id: string;
  text: string;
}

export interface FirstWeekRetentionDebugReport {
  generatedAt: string;
  withinFirstWeek: boolean;
  dayIndex: number | null;
  milestones: FirstWeekMilestone[];
  timingRecommendations: FirstWeekTimingRecommendation[];
  attachmentLevel: ArchiveAttachmentLevel;
  attachmentEvidence: string[];
  firstSessionComplete: boolean;
  firstRevisitDelayHours: number | null;
  revisitConversion: string;
  attachmentEmergence: string;
  ignoredPromptCount: number;
  promptsShownThisWeek: number;
  silenceEffective: boolean;
  retentionRisks: string[];
  emotionalPayoffCandidates: Array<{
    entryId: string;
    score: number;
    firstLine: string;
    signals: string[];
  }>;
  instrumentation: Record<string, number>;
  activeGentlePrompt: GentleReturnPromptOffer | null;
  activeArchiveValueLine: ArchiveValueMomentOffer | null;
}
