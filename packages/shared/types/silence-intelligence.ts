export type SilenceIntelligenceState =
  | "normal"
  | "quiet"
  | "very_quiet"
  | "almost_silent";

export type SilenceIntelligenceSignalId =
  | "ignored_recent_callbacks"
  | "revisit_fatigue"
  | "emotional_saturation"
  | "too_many_notes"
  | "record_only_preference"
  | "heavy_entries_low_action"
  | "closes_without_continuing"
  | "low_onboarding_aha"
  | "weak_return_triggers"
  | "ignored_gentle_prompts"
  | "silence_helped_return"
  | "silence_harmed_behavior"
  | "high_quality_revisit_available"
  | "archive_care_during_silence";

export type SilenceIntelligenceSurface =
  | "memory_note"
  | "followup"
  | "roundup_prompt"
  | "emotional_proof"
  | "resurfacing";

export interface SilenceIntelligenceSignal {
  id: SilenceIntelligenceSignalId;
  label: string;
  detail: string;
  weight: number;
}

export interface SilenceIntelligenceEffects {
  suppressMemoryNotes: boolean;
  suppressFollowups: boolean;
  suppressRoundupPrompts: boolean;
  suppressEmotionalProof: boolean;
  delayResurfacing: boolean;
  essentialsOnly: boolean;
  allowRareResurfacing: boolean;
  postReflectionMinimal: boolean;
  qualityThresholdRequired: number;
}

export interface SilenceIntelligenceRetentionSignals {
  onboardingAhaRate: string;
  returnAfterSilenceCount: number;
  reflectionDuringSilenceCount: number;
  revisitAfterSilenceCount: number;
  ignoredPromptCount: number;
  highQualityRevisitAvailable: boolean;
  bestRevisitScore: number | null;
  exportBackupDuringSilence: boolean;
  voluntaryReturnCount: number;
}

export interface SilenceIntelligenceReport {
  generatedAt: string;
  enabled: boolean;
  state: SilenceIntelligenceState;
  score: number;
  signals: SilenceIntelligenceSignal[];
  effects: SilenceIntelligenceEffects;
  userLine: string | null;
  lastSurfacedNoteId: string | null;
  lastSurfacedNoteAt: string | null;
  ignoredNoteCount: number;
  returnAfterSilence: boolean;
  silenceImprovedRevisit: boolean | null;
  stateEnteredAt: string | null;
}

export interface SilenceIntelligenceDebugReport extends SilenceIntelligenceReport {
  recentStateTransitions: Array<{
    from: SilenceIntelligenceState;
    to: SilenceIntelligenceState;
    at: string;
  }>;
  reflectionsDuringSilence: number;
  activationReason: string;
  suppressedSurfaces: string[];
  silenceHelped: boolean;
  silenceHarmed: boolean;
  nextResurfacingWindow: string | null;
  retentionSignals: SilenceIntelligenceRetentionSignals;
}
