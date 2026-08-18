export type ResurfacingWhyNowKind =
  | "repeated_phrase_after_gap"
  | "repeated_concern_after_gap"
  | "named_person_topic_return"
  | "same_time_of_day"
  | "same_weekday"
  | "same_emotional_state"
  | "mood_shift_same_topic"
  | "quiet_gap_return"
  | "repeated_avoidance_language"
  | "repeated_future_language";

export interface ResurfacingWhyNowSignal {
  kind: ResurfacingWhyNowKind;
  strength: number;
  evidence: string[];
  gapDays?: number;
  entityName?: string;
  phrase?: string;
}

export interface ResurfacingWhyNowVerdict {
  noteId: string;
  entryId?: string;
  text: string;
  explanation: string | null;
  primaryKind: ResurfacingWhyNowKind | null;
  signals: ResurfacingWhyNowSignal[];
  evidenceBacked: boolean;
  blockedReason: string | null;
}

export interface ResurfacingWhyNowReviewRow {
  noteId: string;
  entryId: string;
  text: string;
  explanation: string | null;
  primaryKind: ResurfacingWhyNowKind | null;
  signalCount: number;
  signals: ResurfacingWhyNowSignal[];
  evidenceBacked: boolean;
  blockedReason: string | null;
}

export interface ResurfacingWhyNowDebugReport {
  generatedAt: string;
  hasData: boolean;
  totalCandidates: number;
  withExplanation: ResurfacingWhyNowReviewRow[];
  withoutExplanation: ResurfacingWhyNowReviewRow[];
  byKind: Record<ResurfacingWhyNowKind, number>;
  topExplanations: Array<{ explanation: string; count: number }>;
  blockedSamples: ResurfacingWhyNowReviewRow[];
}
