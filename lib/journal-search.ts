import {
  semanticLifeSearch,
  type LifeSearchField,
} from "@/lib/semantic-life-search";
import type { JournalEntry } from "@/types/journal";

/** @deprecated Use semanticLifeSearch from lib/semantic-life-search */
export type SearchField = Exclude<LifeSearchField, "entity" | "recommendation">;

export interface SearchResult {
  entry: JournalEntry;
  matchedFields: SearchField[];
  snippet: string;
}

export function searchJournalEntries(query: string): SearchResult[] {
  const q = query.trim();
  if (!q) return [];

  return semanticLifeSearch(q).map((result) => {
    const matchedFields = result.matches
      .map((m) => m.field)
      .filter(
        (f): f is SearchField =>
          f !== "entity" && f !== "recommendation",
      );
    const primary =
      result.matches.find((m) => m.field === "transcript") ?? result.matches[0];

    return {
      entry: result.entry,
      matchedFields,
      snippet: primary?.snippet ?? "",
    };
  });
}

export const SEARCH_FIELD_LABELS: Record<SearchField, string> = {
  transcript: "Transcript",
  mood: "Mood",
  themes: "Themes",
  hiddenConcern: "Hidden concern",
  positiveSignal: "Positive signal",
};
