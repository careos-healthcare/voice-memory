export type IdentityFrame =
  | "what_changed"
  | "what_repeated"
  | "what_faded"
  | "what_calmer"
  | "what_clearer";

export type CalmObservationKind =
  | "calmness"
  | "small_evolution"
  | "landmark"
  | "continuity";

export interface CalmObservation {
  id: string;
  text: string;
  detail?: string;
  frame?: IdentityFrame;
  kind: CalmObservationKind;
  confidence: number;
  entryIds: string[];
  quote?: string;
}

export interface MemoryLandmark {
  id: string;
  text: string;
  detail?: string;
  dateLabel?: string;
  entryIds: string[];
  confidence: number;
}

export type ReflectiveSilenceMode = "sentence" | "quote" | "contrast";

export interface ReflectiveSilence {
  mode: ReflectiveSilenceMode;
  primary: string;
  secondary?: string;
  entryId?: string;
}

export type CalmnessScope = "archive" | "weekly" | "monthly" | "entry";

export interface CalmnessReport {
  score: number;
  observations: CalmObservation[];
  landmarks: MemoryLandmark[];
  smallEvolution: CalmObservation[];
  byFrame: Record<IdentityFrame, CalmObservation[]>;
  silence?: ReflectiveSilence;
  hasData: boolean;
  generatedAt: string;
  scope: CalmnessScope;
}

export const IDENTITY_FRAME_LABELS: Record<IdentityFrame, string> = {
  what_changed: "What changed?",
  what_repeated: "What repeated?",
  what_faded: "What faded?",
  what_calmer: "What became calmer?",
  what_clearer: "What became clearer?",
};
