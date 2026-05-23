export interface Reflection {
  mood: string;
  emotionalIntensity: number;
  recurringThemes: string[];
  /** Legacy — kept for search/export compatibility; de-emphasized in UI. */
  hiddenConcern: string;
  /** Legacy — kept for search/export compatibility; de-emphasized in UI. */
  positiveSignal: string;
  /** Legacy — kept for search/export compatibility; de-emphasized in UI. */
  recommendation: string;
  /** Short quote or paraphrase of exact wording from the transcript. */
  exactLanguagePattern?: string;
  /** Concrete, transcript-grounded observation (no vague therapy phrasing). */
  concreteObservation?: string;
  /** Pattern that showed up more than once in this entry. */
  repeatedSignal?: string;
  /** Legacy action field — de-emphasized in UI. */
  nextSmallAction?: string;
  /** Observation-style statements: "You repeatedly…", "You tend to…" */
  patternObservations?: string[];
}

export interface JournalEntry {
  id: string;
  createdAt: string;
  transcript: string;
  reflection: Reflection;
  durationSeconds: number;
  /** Set when original recording is stored in IndexedDB. */
  audioId?: string;
}

export type ProcessingStage = "transcribing" | "analyzing" | "saving";
