export type TranscriptCleanupConfidence = "high" | "medium" | "low";

export type PreservedPhraseReason =
  | "repeated_exact"
  | "emotional_load"
  | "unusual_wording"
  | "self_specific"
  | "named_entity"
  | "pattern_match";

export interface PreservedPhrase {
  text: string;
  reason: PreservedPhraseReason;
}

export interface CollapsedRepetition {
  original: string;
  collapsed: string;
}

export interface PunctuationChange {
  kind: "sentence_break" | "question_mark" | "pause_normalized";
  at: number;
  detail: string;
}

export interface TranscriptCleanupResult {
  rawTranscript: string;
  cleanedTranscript: string;
  preservedPhrases: PreservedPhrase[];
  removedFillers: string[];
  collapsedRepetitions: CollapsedRepetition[];
  punctuationChanges: PunctuationChange[];
  confidence: TranscriptCleanupConfidence;
  cleanupWarnings: string[];
}

export interface TranscriptCleanupMeta {
  preservedPhrases: string[];
  confidence: TranscriptCleanupConfidence;
  appliedAt: string;
}
