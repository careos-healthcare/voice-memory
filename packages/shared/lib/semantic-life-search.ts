import { toDayKey } from "@/lib/dates";
import { buildEntityMemory } from "@/lib/entity-memory";
import { getEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export type LifeSearchField =
  | "transcript"
  | "mood"
  | "themes"
  | "hiddenConcern"
  | "positiveSignal"
  | "recommendation"
  | "concreteObservation"
  | "entity";

export type ConfidenceLabel = "high" | "medium" | "low";

export interface LifeSearchFilters {
  mood: string;
  theme: string;
  dateFrom: string;
  dateTo: string;
  intensityMin: number | null;
  intensityMax: number | null;
}

export const EMPTY_LIFE_SEARCH_FILTERS: LifeSearchFilters = {
  mood: "",
  theme: "",
  dateFrom: "",
  dateTo: "",
  intensityMin: null,
  intensityMax: null,
};

export interface FieldMatch {
  field: LifeSearchField;
  matchedPhrase: string;
  snippet: string;
}

export interface LifeSearchResult {
  entry: JournalEntry;
  score: number;
  matchLabel: ConfidenceLabel;
  matches: FieldMatch[];
}

export interface ParsedLifeQuery {
  terms: string[];
  moodHints: string[];
  intent: "mood" | "mention" | "topic" | "general";
  displayFocus: string;
}

export interface LifeSearchFilterOptions {
  moods: string[];
  themes: string[];
}

export const LIFE_SEARCH_FIELD_LABELS: Record<LifeSearchField, string> = {
  transcript: "Transcript",
  mood: "Mood",
  themes: "Themes",
  hiddenConcern: "Hidden concern",
  positiveSignal: "Positive signal",
  recommendation: "Recommendation",
  concreteObservation: "Concrete observation",
  entity: "Entity memory",
};

const STOPWORDS = new Set([
  "a",
  "an",
  "the",
  "and",
  "or",
  "but",
  "in",
  "on",
  "at",
  "to",
  "for",
  "of",
  "with",
  "by",
  "from",
  "as",
  "is",
  "was",
  "were",
  "be",
  "been",
  "being",
  "have",
  "has",
  "had",
  "do",
  "does",
  "did",
  "will",
  "would",
  "could",
  "should",
  "may",
  "might",
  "must",
  "i",
  "me",
  "my",
  "myself",
  "we",
  "our",
  "you",
  "your",
  "it",
  "its",
  "this",
  "that",
  "these",
  "those",
  "what",
  "which",
  "who",
  "when",
  "where",
  "why",
  "how",
  "all",
  "any",
  "both",
  "each",
  "few",
  "more",
  "most",
  "other",
  "some",
  "such",
  "no",
  "nor",
  "not",
  "only",
  "own",
  "same",
  "so",
  "than",
  "too",
  "very",
  "can",
  "just",
  "don",
  "now",
  "feel",
  "feeling",
  "felt",
  "mention",
  "mentioned",
  "mentions",
  "times",
  "entries",
  "entry",
  "about",
  "did",
]);

const MOOD_LEXICON: Record<string, string[]> = {
  anxious: ["anxious", "anxiety", "worried", "worry", "nervous", "uneasy", "on edge"],
  stressed: ["stressed", "stress", "overwhelmed", "pressure", "burned out", "burnt out"],
  sad: ["sad", "sadness", "down", "low", "depressed", "heavy"],
  angry: ["angry", "anger", "frustrated", "frustration", "irritated"],
  hopeful: ["hopeful", "hope", "optimistic", "encouraged", "positive"],
  calm: ["calm", "peaceful", "relaxed", "steady", "grounded"],
  happy: ["happy", "happiness", "joy", "joyful", "grateful", "gratitude"],
  tired: ["tired", "exhausted", "fatigue", "drained"],
  lonely: ["lonely", "loneliness", "isolated", "alone"],
  confused: ["confused", "uncertain", "unsure", "lost"],
};

const NL_PATTERNS: Array<{
  re: RegExp;
  intent: ParsedLifeQuery["intent"];
  group: number;
}> = [
  { re: /^when\s+(?:did|was)\s+i\s+feel(?:ing)?\s+(.+)$/i, intent: "mood", group: 1 },
  { re: /^when\s+was\s+i\s+(.+)$/i, intent: "mood", group: 1 },
  { re: /^times?\s+i\s+mentioned\s+(.+)$/i, intent: "mention", group: 1 },
  { re: /^entries?\s+about\s+(.+)$/i, intent: "topic", group: 1 },
  { re:/^moments?\s+about\s+(.+)$/i, intent: "topic", group: 1 },
  { re: /^when\s+(?:did|was)\s+i\s+(.+)$/i, intent: "mood", group: 1 },
  { re: /^show\s+me\s+(.+)$/i, intent: "general", group: 1 },
  { re: /^find\s+(.+)$/i, intent: "general", group: 1 },
];

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^\w\s'-]/g, " ")
    .split(/\s+/)
    .map((t) => t.trim())
    .filter((t) => t.length > 1 && !STOPWORDS.has(t));
}

function expandMoodHints(phrase: string): string[] {
  const lower = phrase.toLowerCase().trim();
  const hints = new Set<string>(tokenize(lower));

  for (const [canonical, synonyms] of Object.entries(MOOD_LEXICON)) {
    if (synonyms.some((s) => lower.includes(s)) || lower.includes(canonical)) {
      hints.add(canonical);
      for (const s of synonyms) hints.add(s);
    }
  }

  for (const token of tokenize(lower)) {
    for (const [canonical, synonyms] of Object.entries(MOOD_LEXICON)) {
      if (synonyms.includes(token) || canonical === token) {
        hints.add(canonical);
        synonyms.forEach((s) => hints.add(s));
      }
    }
  }

  return [...hints];
}

export function parseLifeQuery(rawQuery: string): ParsedLifeQuery {
  const raw = rawQuery.trim();
  if (!raw) {
    return { terms: [], moodHints: [], intent: "general", displayFocus: "" };
  }

  let intent: ParsedLifeQuery["intent"] = "general";
  let focus = raw;

  for (const pattern of NL_PATTERNS) {
    const match = raw.match(pattern.re);
    if (match?.[pattern.group]) {
      intent = pattern.intent;
      focus = match[pattern.group].trim();
      break;
    }
  }

  const terms = tokenize(focus);
  const moodHints =
    intent === "mood" ? expandMoodHints(focus) : expandMoodHints(focus).slice(0, 6);

  if (intent !== "mood" && moodHints.length > 0 && terms.length <= 2) {
    // e.g. "hopeful" without "when was i"
    const maybeMood = expandMoodHints(raw);
    if (maybeMood.length > terms.length) {
      moodHints.push(...maybeMood);
    }
  }

  return {
    terms,
    moodHints: [...new Set(moodHints)],
    intent,
    displayFocus: focus,
  };
}

function buildEntryEntityMap(): Map<string, string[]> {
  const snapshot = buildEntityMemory();
  const all = [
    ...snapshot.people,
    ...snapshot.concerns,
    ...snapshot.goals,
    ...snapshot.topics,
  ];

  const map = new Map<string, string[]>();

  for (const entity of all) {
    for (const entryId of entity.entryIds) {
      const list = map.get(entryId) ?? [];
      if (!list.includes(entity.name)) {
        list.push(entity.name);
      }
      map.set(entryId, list);
    }
  }

  return map;
}

function haystack(entry: JournalEntry, field: LifeSearchField, entities: string[]): string {
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
    case "recommendation":
      return [
        entry.reflection.recommendation,
        entry.reflection.nextSmallAction ?? "",
      ].join(" ");
    case "concreteObservation":
      return [
        entry.reflection.concreteObservation ?? "",
        entry.reflection.exactLanguagePattern ?? "",
        entry.reflection.repeatedSignal ?? "",
      ].join(" ");
    case "entity":
      return entities.join(" ");
  }
}

function excerptAround(text: string, needle: string, radius = 64): string {
  const lower = text.toLowerCase();
  const n = needle.toLowerCase();
  const index = lower.indexOf(n);

  if (index === -1) {
    const trimmed = text.trim();
    return trimmed.slice(0, radius * 2) + (trimmed.length > radius * 2 ? "…" : "");
  }

  const start = Math.max(0, index - radius);
  const end = Math.min(text.length, index + needle.length + radius);
  const prefix = start > 0 ? "…" : "";
  const suffix = end < text.length ? "…" : "";
  return prefix + text.slice(start, end).trim() + suffix;
}

function bestPhraseInText(
  text: string,
  terms: string[],
  moodHints: string[],
): string | null {
  const lower = text.toLowerCase();

  for (const hint of moodHints) {
    if (lower.includes(hint.toLowerCase())) return hint;
  }

  for (const term of terms) {
    if (lower.includes(term)) return term;
  }

  return terms[0] ?? moodHints[0] ?? null;
}

function scoreField(
  text: string,
  terms: string[],
  moodHints: string[],
  intent: ParsedLifeQuery["intent"],
  field: LifeSearchField,
): { score: number; phrase: string | null } {
  const lower = text.toLowerCase();
  if (!text.trim()) return { score: 0, phrase: null };

  let score = 0;
  let matchedPhrase: string | null = null;

  const focusPhrase = [...moodHints, ...terms].join(" ").trim();
  if (focusPhrase.length >= 4 && lower.includes(focusPhrase.toLowerCase())) {
    score += 8;
    matchedPhrase = focusPhrase;
  }

  for (const hint of moodHints) {
    if (lower.includes(hint.toLowerCase())) {
      score += field === "mood" ? 6 : 3;
      matchedPhrase = matchedPhrase ?? hint;
    }
  }

  let termHits = 0;
  for (const term of terms) {
    if (lower.includes(term)) {
      termHits += 1;
      score += 2;
      matchedPhrase = matchedPhrase ?? term;
    }
  }

  if (terms.length > 1 && termHits === terms.length) {
    score += 4;
  }

  if (intent === "mood" && (field === "mood" || field === "positiveSignal")) {
    score += termHits > 0 || moodHints.some((h) => lower.includes(h)) ? 3 : 0;
  }

  if (intent === "mention" && field === "transcript") {
    score += termHits > 0 ? 2 : 0;
  }

  if (intent === "topic" && (field === "themes" || field === "hiddenConcern")) {
    score += termHits > 0 ? 2 : 0;
  }

  if (score > 0 && !matchedPhrase) {
    matchedPhrase = bestPhraseInText(text, terms, moodHints);
  }

  return { score, phrase: score > 0 ? matchedPhrase : null };
}

function toConfidence(score: number, matchCount: number): ConfidenceLabel {
  if (score >= 12 || matchCount >= 3) return "high";
  if (score >= 6 || matchCount >= 2) return "medium";
  return "low";
}

function passesFilters(entry: JournalEntry, filters: LifeSearchFilters): boolean {
  if (filters.mood) {
    if (entry.reflection.mood.toLowerCase() !== filters.mood.toLowerCase()) {
      return false;
    }
  }

  if (filters.theme) {
    const hasTheme = entry.reflection.recurringThemes.some(
      (t) => t.toLowerCase() === filters.theme.toLowerCase(),
    );
    if (!hasTheme) return false;
  }

  const day = toDayKey(entry.createdAt);

  if (filters.dateFrom && day < filters.dateFrom) return false;
  if (filters.dateTo && day > filters.dateTo) return false;

  const intensity = entry.reflection.emotionalIntensity;
  if (filters.intensityMin !== null && intensity < filters.intensityMin) return false;
  if (filters.intensityMax !== null && intensity > filters.intensityMax) return false;

  return true;
}

const SEARCH_FIELDS: LifeSearchField[] = [
  "transcript",
  "mood",
  "themes",
  "concreteObservation",
  "hiddenConcern",
  "positiveSignal",
  "recommendation",
  "entity",
];

export function getLifeSearchFilterOptions(): LifeSearchFilterOptions {
  const entries = getEntries();
  const moodSet = new Set<string>();
  const themeSet = new Set<string>();

  for (const entry of entries) {
    moodSet.add(entry.reflection.mood.trim());
    for (const theme of entry.reflection.recurringThemes) {
      const t = theme.trim();
      if (t) themeSet.add(t);
    }
  }

  return {
    moods: [...moodSet].sort((a, b) => a.localeCompare(b)),
    themes: [...themeSet].sort((a, b) => a.localeCompare(b)),
  };
}

export function semanticLifeSearch(
  rawQuery: string,
  filters: LifeSearchFilters = EMPTY_LIFE_SEARCH_FILTERS,
): LifeSearchResult[] {
  const parsed = parseLifeQuery(rawQuery);
  const hasQuery =
    parsed.terms.length > 0 ||
    parsed.moodHints.length > 0 ||
    parsed.displayFocus.length > 0;

  const hasFilters =
    Boolean(filters.mood) ||
    Boolean(filters.theme) ||
    Boolean(filters.dateFrom) ||
    Boolean(filters.dateTo) ||
    filters.intensityMin !== null ||
    filters.intensityMax !== null;

  if (!hasQuery && !hasFilters) return [];

  const entityMap = buildEntryEntityMap();
  const results: LifeSearchResult[] = [];

  for (const entry of getEntries()) {
    if (!passesFilters(entry, filters)) continue;

    const entities = entityMap.get(entry.id) ?? [];
    const fieldMatches: FieldMatch[] = [];
    let totalScore = 0;

    if (!hasQuery) {
      results.push({
        entry,
        score: 1,
        matchLabel: "low",
        matches: [
          {
            field: "mood",
            matchedPhrase: entry.reflection.mood,
            snippet: entry.reflection.positiveSignal.slice(0, 120),
          },
        ],
      });
      continue;
    }

    for (const field of SEARCH_FIELDS) {
      const text = haystack(entry, field, entities);
      const { score, phrase } = scoreField(
        text,
        parsed.terms,
        parsed.moodHints,
        parsed.intent,
        field,
      );

      if (score > 0 && phrase) {
        totalScore += score;
        fieldMatches.push({
          field,
          matchedPhrase: phrase,
          snippet: excerptAround(text, phrase),
        });
      }
    }

    if (fieldMatches.length === 0) continue;

    fieldMatches.sort((a, b) => {
      const order: LifeSearchField[] = SEARCH_FIELDS;
      return order.indexOf(a.field) - order.indexOf(b.field);
    });

    const top = fieldMatches[0];

    results.push({
      entry,
      score: totalScore,
      matchLabel: toConfidence(totalScore, fieldMatches.length),
      matches: fieldMatches.slice(0, 4),
    });
  }

  return results.sort((a, b) => b.score - a.score);
}

export const EXAMPLE_LIFE_QUERIES = [
  "when did I feel anxious?",
  "times I mentioned money",
  "entries about family pressure",
  "when was I hopeful?",
] as const;
