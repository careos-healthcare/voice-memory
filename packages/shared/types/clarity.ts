export type ThoughtPatternKind =
  | "assumption"
  | "avoided_speech"
  | "repeated_concern"
  | "desired_response"
  | "unresolved_question"
  | "emotional_trigger";

export interface ThoughtPattern {
  kind: ThoughtPatternKind;
  /** User-owned wording — quote-like, never a label or diagnosis. */
  quote: string;
}

export interface ThinkingOutLoudSignals {
  conflictLikely: boolean;
  uncertaintyLikely: boolean;
  avoidedSpeechLikely: boolean;
  repeatedThoughtLikely: boolean;
  confidence: number;
  matchedPhrases: string[];
}

export interface ClarityPromptOffer {
  entryId: string;
  signals: ThinkingOutLoudSignals;
}

export interface CirclingThoughtsDisplay {
  entryId: string;
  items: ThoughtPattern[];
}

export type ClarityRecorderPromptKey =
  | "what_happened"
  | "what_assumed"
  | "what_avoided"
  | "what_unresolved"
  | "what_changed";
