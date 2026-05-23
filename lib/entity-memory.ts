import { toDayKey } from "@/lib/dates";
import { getEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export type EntityType =
  | "person"
  | "place"
  | "company"
  | "goal"
  | "fear"
  | "topic";

export interface TrackedEntity {
  /** Stable key for grouping (normalized). */
  id: string;
  name: string;
  type: EntityType;
  mentionCount: number;
  firstMentionedAt: string;
  lastMentionedAt: string;
  relatedMoods: string[];
  relatedThemes: string[];
  sampleEntryIds: string[];
  entryIds: string[];
}

export interface MentionHighlight {
  name: string;
  type: EntityType;
  mentionCount: number;
}

export interface EntityMemorySnapshot {
  people: TrackedEntity[];
  concerns: TrackedEntity[];
  goals: TrackedEntity[];
  topics: TrackedEntity[];
  mentionHighlights: MentionHighlight[];
  totalEntities: number;
  hasData: boolean;
}

interface RawMention {
  name: string;
  type: EntityType;
  entryId: string;
  createdAt: string;
  mood: string;
  themes: string[];
}

const MAX_SAMPLE_ENTRIES = 5;
const MIN_MENTIONS_PERSON = 1;
const MIN_MENTIONS_PLACE = 2;
const MIN_MENTIONS_COMPANY = 2;
const MIN_MENTIONS_GOAL = 1;
const MIN_MENTIONS_FEAR = 1;
const MIN_MENTIONS_TOPIC = 1;

const COMMON_WORDS = new Set([
  "the",
  "and",
  "for",
  "that",
  "this",
  "with",
  "from",
  "your",
  "have",
  "been",
  "were",
  "they",
  "what",
  "when",
  "where",
  "which",
  "while",
  "about",
  "into",
  "just",
  "like",
  "really",
  "very",
  "also",
  "then",
  "than",
  "them",
  "their",
  "there",
  "would",
  "could",
  "should",
  "because",
  "something",
  "someone",
  "today",
  "yesterday",
  "tomorrow",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
  "january",
  "february",
  "march",
  "april",
  "may",
  "june",
  "july",
  "august",
  "september",
  "october",
  "november",
  "december",
  "work",
  "home",
  "school",
  "office",
  "here",
  "there",
  "today",
  "tomorrow",
  "voice",
  "memory",
]);

const NAME_STOPWORDS = new Set([
  "I",
  "The",
  "This",
  "That",
  "What",
  "When",
  "Where",
  "How",
  "Why",
  "But",
  "And",
  "Or",
  "So",
  "If",
  "Then",
  "Just",
  "Really",
  "Today",
  "Yesterday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
  "God",
  "Okay",
  "Yeah",
  "Yes",
  "No",
]);

const RELATIONSHIP_PATTERN =
  /\bmy\s+(mom|mother|dad|father|parent|parents|partner|wife|husband|spouse|boss|manager|friend|friends|therapist|doctor|sister|brother|son|daughter|kids|child|children|colleague|coworker|team)\b/gi;

const PLACE_LITERALS = new Set([
  "home",
  "work",
  "school",
  "the office",
  "office",
]);

const GOAL_PATTERN =
  /\b(?:want to|need to|goal is to|goal to|trying to|planning to|hope to|hoping to|working toward|work toward)\s+([^.!?\n]{5,72})/gi;

const FEAR_PATTERN =
  /\b(?:worried about|afraid of|anxious about|scared of|fear of|fearing|stress about|stressed about)\s+([^.!?\n]{4,72})/gi;

const COMPANY_SUFFIX_PATTERN = /\b([A-Z][a-zA-Z0-9&]+(?:\s+[A-Z][a-zA-Z0-9&]+)*)\s+(?:Inc\.?|LLC|Corp\.?|Ltd\.?)\b/g;

const PREPOSITION_PLACE_PATTERN =
  /\b(?:in|at|from|to)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b/g;

const AT_ORG_PATTERN = /\b(?:at|for|with)\s+([A-Z][a-zA-Z][a-zA-Z0-9]{2,})\b/g;

function normalizeKey(name: string, type: EntityType): string {
  return `${type}:${name.trim().toLowerCase().replace(/\s+/g, " ")}`;
}

function titleCasePhrase(raw: string): string {
  const trimmed = raw.trim().replace(/\s+/g, " ");
  if (!trimmed) return trimmed;
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
}

function cleanPhrase(raw: string, maxLen = 72): string | null {
  let phrase = raw.trim().replace(/\s+/g, " ");
  phrase = phrase.replace(/^(that|this|the|a|an)\s+/i, "");
  if (phrase.length < 4 || phrase.length > maxLen) return null;

  const words = phrase.toLowerCase().split(/\s+/);
  if (words.every((w) => COMMON_WORDS.has(w))) return null;

  return titleCasePhrase(phrase);
}

function isValidCapitalizedName(word: string): boolean {
  if (word.length < 3) return false;
  if (NAME_STOPWORDS.has(word)) return false;
  if (/^\d/.test(word)) return false;
  return true;
}

function addMention(
  bucket: RawMention[],
  name: string,
  type: EntityType,
  entry: JournalEntry,
): void {
  const cleaned = cleanPhrase(name, type === "topic" ? 48 : 72);
  if (!cleaned) return;

  bucket.push({
    name: cleaned,
    type,
    entryId: entry.id,
    createdAt: entry.createdAt,
    mood: entry.reflection.mood.trim(),
    themes: entry.reflection.recurringThemes.map((t) => t.trim()).filter(Boolean),
  });
}

function extractFromText(
  text: string,
  entry: JournalEntry,
  bucket: RawMention[],
): void {
  if (!text.trim()) return;

  for (const match of text.matchAll(RELATIONSHIP_PATTERN)) {
    addMention(bucket, match[0], "person", entry);
  }

  const capitalized = text.match(/\b[A-Z][a-z]{2,}\b/g) ?? [];
  for (const word of capitalized) {
    if (isValidCapitalizedName(word)) {
      addMention(bucket, word, "person", entry);
    }
  }

  for (const literal of PLACE_LITERALS) {
    const re = new RegExp(`\\b${literal.replace(/\s+/g, "\\s+")}\\b`, "i");
    if (re.test(text)) {
      addMention(bucket, literal === "office" ? "the office" : literal, "place", entry);
    }
  }

  for (const match of text.matchAll(PREPOSITION_PLACE_PATTERN)) {
    const place = match[1]?.trim();
    if (!place) continue;
    const lower = place.toLowerCase();
    if (COMMON_WORDS.has(lower) || NAME_STOPWORDS.has(place)) continue;
    if (place.split(/\s+/).length > 3) continue;
    addMention(bucket, place, "place", entry);
  }

  for (const match of text.matchAll(COMPANY_SUFFIX_PATTERN)) {
    const company = match[0]?.trim();
    if (company) addMention(bucket, company, "company", entry);
  }

  for (const match of text.matchAll(AT_ORG_PATTERN)) {
    const org = match[1]?.trim();
    if (!org) continue;
    if (NAME_STOPWORDS.has(org) || COMMON_WORDS.has(org.toLowerCase())) continue;
    if (org.length < 3) continue;
    addMention(bucket, org, "company", entry);
  }

  for (const match of text.matchAll(GOAL_PATTERN)) {
    const goal = match[1];
    if (goal) addMention(bucket, goal, "goal", entry);
  }

  for (const match of text.matchAll(FEAR_PATTERN)) {
    const fear = match[1];
    if (fear) addMention(bucket, fear, "fear", entry);
  }
}

function collectMentions(entries: JournalEntry[]): RawMention[] {
  const bucket: RawMention[] = [];

  for (const entry of entries) {
    const { reflection } = entry;
    const combined = [
      entry.transcript,
      reflection.hiddenConcern,
      reflection.positiveSignal,
      reflection.recommendation,
    ].join("\n");

    extractFromText(combined, entry, bucket);

    for (const theme of reflection.recurringThemes) {
      if (theme.trim().length >= 3) {
        addMention(bucket, theme, "topic", entry);
      }
    }

    const concern = reflection.hiddenConcern.trim();
    if (concern.length >= 24 && concern.length <= 120) {
      addMention(bucket, concern, "fear", entry);
    }
  }

  return bucket;
}

function minMentionsForType(type: EntityType): number {
  switch (type) {
    case "person":
      return MIN_MENTIONS_PERSON;
    case "place":
      return MIN_MENTIONS_PLACE;
    case "company":
      return MIN_MENTIONS_COMPANY;
    case "goal":
      return MIN_MENTIONS_GOAL;
    case "fear":
      return MIN_MENTIONS_FEAR;
    case "topic":
      return MIN_MENTIONS_TOPIC;
  }
}

function aggregateMentions(mentions: RawMention[]): TrackedEntity[] {
  const map = new Map<
    string,
    {
      name: string;
      type: EntityType;
      entryIds: string[];
      moods: Map<string, number>;
      themes: Map<string, number>;
      dates: string[];
    }
  >();

  for (const mention of mentions) {
    const id = normalizeKey(mention.name, mention.type);
    let row = map.get(id);

    if (!row) {
      row = {
        name: mention.name,
        type: mention.type,
        entryIds: [],
        moods: new Map(),
        themes: new Map(),
        dates: [],
      };
      map.set(id, row);
    }

    if (!row.entryIds.includes(mention.entryId)) {
      row.entryIds.push(mention.entryId);
    }

    if (mention.mood) {
      const moodKey = mention.mood.toLowerCase();
      row.moods.set(moodKey, (row.moods.get(moodKey) ?? 0) + 1);
    }

    for (const theme of mention.themes) {
      const themeKey = theme.toLowerCase();
      row.themes.set(themeKey, (row.themes.get(themeKey) ?? 0) + 1);
    }

    row.dates.push(mention.createdAt);
  }

  const entities: TrackedEntity[] = [];

  for (const [id, row] of map) {
    const mentionCount = row.entryIds.length;
    if (mentionCount < minMentionsForType(row.type)) continue;

    if (row.type === "person") {
      const isRelationship = row.name.toLowerCase().startsWith("my ");
      const capitalizedOnly = !isRelationship;
      if (capitalizedOnly && mentionCount < 2) continue;
    }

    const sortedDates = [...row.dates].sort(
      (a, b) => new Date(a).getTime() - new Date(b).getTime(),
    );

    const relatedMoods = [...row.moods.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 4)
      .map(([mood]) => mood);

    const relatedThemes = [...row.themes.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([theme]) => theme);

    entities.push({
      id,
      name: row.name,
      type: row.type,
      mentionCount,
      firstMentionedAt: sortedDates[0] ?? "",
      lastMentionedAt: sortedDates[sortedDates.length - 1] ?? "",
      relatedMoods,
      relatedThemes,
      sampleEntryIds: row.entryIds.slice(0, MAX_SAMPLE_ENTRIES),
      entryIds: row.entryIds,
    });
  }

  return entities.sort((a, b) => b.mentionCount - a.mentionCount);
}

function buildMentionHighlights(entities: TrackedEntity[]): MentionHighlight[] {
  return entities
    .filter((e) => e.mentionCount >= 2)
    .slice(0, 8)
    .map((e) => ({
      name: e.name,
      type: e.type,
      mentionCount: e.mentionCount,
    }));
}

export function buildEntityMemoryFromEntries(
  entries: JournalEntry[],
): EntityMemorySnapshot {
  const mentions = collectMentions(entries);
  const all = aggregateMentions(mentions);

  const people = all.filter((e) => e.type === "person");
  const concerns = all.filter((e) => e.type === "fear");
  const goals = all.filter((e) => e.type === "goal");
  const topics = all.filter((e) =>
    ["topic", "place", "company"].includes(e.type),
  );

  const placeAndCompany = all.filter(
    (e) => e.type === "place" || e.type === "company",
  );
  const topicsCombined = [
    ...topics.filter((e) => e.type === "topic"),
    ...placeAndCompany,
  ].sort((a, b) => b.mentionCount - a.mentionCount);

  return {
    people,
    concerns,
    goals,
    topics: topicsCombined,
    mentionHighlights: buildMentionHighlights(all),
    totalEntities: all.length,
    hasData: entries.length > 0,
  };
}

export function buildEntityMemory(): EntityMemorySnapshot {
  return buildEntityMemoryFromEntries(getEntries());
}

export function formatEntityTypeLabel(type: EntityType): string {
  const labels: Record<EntityType, string> = {
    person: "Person",
    place: "Place",
    company: "Company",
    goal: "Goal",
    fear: "Concern",
    topic: "Topic",
  };
  return labels[type];
}

export function formatEntityDateRange(entity: TrackedEntity): string {
  if (!entity.firstMentionedAt) return "";
  const fmt = (iso: string) => {
    const [y, m, d] = toDayKey(iso).split("-").map(Number);
    return new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
    }).format(new Date(y, m - 1, d));
  };
  const start = fmt(entity.firstMentionedAt);
  const end = fmt(entity.lastMentionedAt);
  return start === end ? start : `${start} – ${end}`;
}
