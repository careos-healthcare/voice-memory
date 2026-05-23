import { getEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export type SearchField =
  | "transcript"
  | "mood"
  | "themes"
  | "hiddenConcern"
  | "positiveSignal";

export interface SearchResult {
  entry: JournalEntry;
  matchedFields: SearchField[];
  snippet: string;
}

function normalizeQuery(query: string): string {
  return query.trim().toLowerCase();
}

function haystackForField(entry: JournalEntry, field: SearchField): string {
  switch (field) {
    case "transcript":
      return entry.transcript;
    case "mood":
      return entry.reflection.mood;
    case "themes":
      return entry.reflection.recurringThemes.join(" ");
    case "hiddenConcern":
      return entry.reflection.hiddenConcern;
    case "positiveSignal":
      return entry.reflection.positiveSignal;
  }
}

function excerpt(text: string, query: string, radius = 60): string {
  const lower = text.toLowerCase();
  const index = lower.indexOf(query);
  if (index === -1) {
    return text.slice(0, radius * 2) + (text.length > radius * 2 ? "…" : "");
  }

  const start = Math.max(0, index - radius);
  const end = Math.min(text.length, index + query.length + radius);
  const prefix = start > 0 ? "…" : "";
  const suffix = end < text.length ? "…" : "";
  return prefix + text.slice(start, end).trim() + suffix;
}

export function searchJournalEntries(query: string): SearchResult[] {
  const q = normalizeQuery(query);
  if (!q) return [];

  const fields: SearchField[] = [
    "transcript",
    "mood",
    "themes",
    "hiddenConcern",
    "positiveSignal",
  ];

  const results: SearchResult[] = [];

  for (const entry of getEntries()) {
    const matchedFields: SearchField[] = [];

    for (const field of fields) {
      const haystack = haystackForField(entry, field).toLowerCase();
      if (haystack.includes(q)) {
        matchedFields.push(field);
      }
    }

    if (matchedFields.length === 0) continue;

    const primaryField = matchedFields.includes("transcript")
      ? "transcript"
      : matchedFields[0];
    const snippet = excerpt(haystackForField(entry, primaryField), q);

    results.push({ entry, matchedFields, snippet });
  }

  return results;
}

export const SEARCH_FIELD_LABELS: Record<SearchField, string> = {
  transcript: "Transcript",
  mood: "Mood",
  themes: "Themes",
  hiddenConcern: "Hidden concern",
  positiveSignal: "Positive signal",
};
