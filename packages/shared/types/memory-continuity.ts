import type { JournalEntry } from "@/types/journal";

export type MemoryContinuityMatchReason =
  | "themes"
  | "mood"
  | "entities"
  | "keywords"
  | "concern"
  | "recommendation";

export interface RelatedReflection {
  entry: JournalEntry;
  score: number;
  matchReasons: MemoryContinuityMatchReason[];
  snippet: string;
  daysApart: number;
}

export interface RepeatedConcern {
  label: string;
  count: number;
  daysSincePrevious: number | null;
}

export interface RecurringEmotionalPattern {
  label: string;
  count: number;
  moods: string[];
}

export interface LastMentionedReference {
  label: string;
  kind: "theme" | "entity" | "concern";
  daysAgo: number;
  previousEntryId: string;
}

export interface MemoryContinuityReport {
  mentionAgainLines: string[];
  patternCountLines: string[];
  relatedReflections: RelatedReflection[];
  repeatedConcerns: RepeatedConcern[];
  recurringEmotionalPatterns: RecurringEmotionalPattern[];
  similarFromPreviousWeeks: RelatedReflection[];
  lastMentioned: LastMentionedReference[];
  hasData: boolean;
}
