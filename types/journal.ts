import type { EntryPhotoMeta } from "@/types/personalization";
import type { EntryAtmosphereMeta } from "@/types/atmosphere";
import type { TranscriptCleanupMeta } from "@/types/transcript-cleanup";
import type { ExplainableConclusion } from "@/types/explainability";

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
  /** Tension or contradiction within this entry's language. */
  tensionOrContradiction?: string;
  /** Topic circled without direct naming — vague or indirect phrasing. */
  avoidedOrVagueArea?: string;
  /** Legacy action field — de-emphasized in UI. */
  nextSmallAction?: string;
  /** Observation-style statements: "You repeatedly…", "You tend to…" */
  patternObservations?: string[];
  /** Strictly validated, transcript-addressable conclusion for proof-aware clients. */
  explainableConclusion?: ExplainableConclusion;
}

export interface JournalEntry {
  id: string;
  createdAt: string;
  transcript: string;
  /** Original ASR transcript before quiet cleanup, when preserved. */
  rawTranscript?: string;
  /** Cleanup metadata for preserved phrase anchors. */
  transcriptCleanup?: TranscriptCleanupMeta;
  reflection: Reflection;
  durationSeconds: number;
  /** Set when original recording is stored in IndexedDB. */
  audioId?: string;
  /** Saved in listening mode — reflection generated later on request. */
  reflectionPending?: boolean;
  /** Optional quiet photo attachment — stored locally in IndexedDB. */
  photo?: EntryPhotoMeta;
  /** Optional abstract atmosphere — user-initiated, stored locally. */
  atmosphere?: EntryAtmosphereMeta;
}

export type ProcessingStage = "transcribing" | "analyzing" | "saving";
