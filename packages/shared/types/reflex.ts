export type ReflexTriggerType =
  | "open_loop_resurface"
  | "post_conflict"
  | "late_night"
  | "uncertainty_repeat"
  | "rapid_callback_reopen"
  | "rumination_phrase";

export interface ReflexCaptureResult {
  likelyReflexMoment: boolean;
  triggerType: ReflexTriggerType | null;
  bypassScore: number;
  shouldBypassHomepage: boolean;
  continuityLine: string | null;
  anchorQuote: string | null;
  noteId: string | null;
}

export interface ReadVsSpeakMetrics {
  avgSecondsBeforeRecord: number | null;
  callbackOpensWithoutRecord: number;
  repeatedReopenWithoutRecord: number;
  scrollBeforeRecordSignals: number;
  consumableContinuityRisk: boolean;
  passiveReadingLikely: boolean;
}

export interface ReadVsSpeakReport {
  metrics: ReadVsSpeakMetrics;
  warnings: Array<{ id: string; message: string }>;
}

export interface ReflexScoreSnapshot {
  resurfacingToImmediateRecord: number;
  unresolvedReturnScore: number;
  speedToSpeakScore: number;
  emotionalRecurrenceTiming: number;
  lateNightReflexUsage: number;
  conflictRepeatScore: number;
  overall: number;
}
