export interface Reflection {
  mood: string;
  emotionalIntensity: number;
  recurringThemes: string[];
  hiddenConcern: string;
  positiveSignal: string;
  recommendation: string;
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
