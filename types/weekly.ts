import type { ExplainableConclusion } from "@/types/explainability";

/** Payload sent to weekly reflection API (aggregates only, no raw audio). */
export interface WeeklyReflectionPayload {
  weekEndingKey: string;
  entryCount: number;
  lastWeekEntryCount: number;
  dominantEmotions: string[];
  repeatedConcerns: string[];
  repeatedEntities: string[];
  recurringThemes: string[];
  avgIntensityThisWeek: number | null;
  avgIntensityLastWeek: number | null;
  emotionalShiftLabel: string;
  observationHighlights: string[];
  /** Optional proof sources. Without these, the route will not generate AI prose. */
  citationSources?: Array<{
    entryId: string;
    canonicalTranscript: string;
  }>;
}

export interface WeeklyReflectionResponse {
  /** Flat compatibility field; present only with a validated conclusion. */
  summary?: string;
  explainableConclusion?: ExplainableConclusion;
  unavailable?: boolean;
  code?: "VERIFIABLE_SOURCES_REQUIRED" | "CONCLUSION_VALIDATION_FAILED";
}
