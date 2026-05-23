export interface Reflection {
  mood: string;
  emotionalIntensity: number;
  recurringThemes: string[];
  hiddenConcern: string;
  positiveSignal: string;
  recommendation: string;
  /** Short quote or paraphrase of exact wording from the transcript. */
  exactLanguagePattern?: string;
  /** Concrete, transcript-grounded observation (no vague therapy phrasing). */
  concreteObservation?: string;
  /** Pattern that showed up more than once in this entry. */
  repeatedSignal?: string;
  /** One small, specific action for the next 24 hours. */
  nextSmallAction?: string;
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
