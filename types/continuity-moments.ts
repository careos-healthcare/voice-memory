export type ContinuityMomentKind =
  | "first_calmer_mention"
  | "first_direct_mention"
  | "last_concern_appearance"
  | "recovery_after_spike"
  | "phrase_disappearance"
  | "topic_resolved"
  | "loop_returning";

export type ContinuityCallbackKind =
  | "came_up_differently"
  | "sounds_calmer"
  | "first_direct"
  | "used_to_be_vague"
  | "topic_stopped"
  | "sounds_different";

export type ContinuityContext = "entry" | "weekly" | "monthly" | "memory" | "timeline";

export interface ContinuityCallback {
  id: string;
  text: string;
  kind: ContinuityCallbackKind;
  confidence: number;
  entryIds: string[];
  anchorEntryId?: string;
}

export interface ContinuityMoment {
  id: string;
  kind: ContinuityMomentKind;
  text: string;
  detail?: string;
  confidence: number;
  entryIds: string[];
  dateLabel?: string;
}

export interface ThenVsNowComparison {
  headline: string;
  then: {
    entryId: string;
    dateLabel: string;
    snippet: string;
  };
  now: {
    entryId: string;
    dateLabel: string;
    snippet: string;
  };
  confidence: number;
  subject: string;
}

export interface ContinuityMomentsReport {
  callbacks: ContinuityCallback[];
  moments: ContinuityMoment[];
  landmarks: ContinuityMoment[];
  thenVsNow?: ThenVsNowComparison;
  hasData: boolean;
  context: ContinuityContext;
  generatedAt: string;
}
