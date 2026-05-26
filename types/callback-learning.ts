export type CallbackLearningEventName =
  | "callback_shown"
  | "callback_ignored"
  | "callback_opened"
  | "callback_reread"
  | "callback_saved"
  | "callback_shared"
  | "callback_dismissed"
  | "reflection_after_callback"
  | "return_after_callback";

export type CallbackLearningKind =
  | "repeated_phrase"
  | "repeated_concern"
  | "mood_shift"
  | "named_person_topic"
  | "time_gap"
  | "audio_photo_anchored";

export interface CallbackLearningWeights {
  repeated_phrase: number;
  repeated_concern: number;
  mood_shift: number;
  named_person_topic: number;
  time_gap: number;
  audio_photo_anchored: number;
}

export interface CallbackLearningEventRow {
  event: CallbackLearningEventName;
  at: string;
  noteId: string;
  kinds: CallbackLearningKind[];
}

export interface CallbackLearningVerdict {
  noteId: string;
  kinds: CallbackLearningKind[];
  weights: CallbackLearningWeights;
  rankAdjustment: number;
  interactionBoost: number;
}

export interface CallbackLearningReviewRow {
  noteId: string;
  text: string;
  kinds: CallbackLearningKind[];
  rankAdjustment: number;
  interactionBoost: number;
}

export interface CallbackLearningDebugReport {
  generatedAt: string;
  hasData: boolean;
  weights: CallbackLearningWeights;
  eventCounts: Record<CallbackLearningEventName, number>;
  totalEvents: number;
  topBoostedKinds: Array<{ kind: CallbackLearningKind; weight: number }>;
  topReducedKinds: Array<{ kind: CallbackLearningKind; weight: number }>;
  recentEvents: CallbackLearningEventRow[];
  sampleAdjustments: CallbackLearningReviewRow[];
}
