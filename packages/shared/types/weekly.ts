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
}

export interface WeeklyReflectionResponse {
  summary: string;
}
