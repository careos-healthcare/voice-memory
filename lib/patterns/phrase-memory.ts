import { toDayKey } from "@/lib/dates";
import { getCachedPhraseMemory } from "@/lib/performance/phrase-scan-cache";
import { transcriptForPhraseScanning } from "@/lib/transcript/transcript-cleanup";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export type PhraseCategory =
  | "linguistic_habit"
  | "metaphor"
  | "self_label"
  | "framing";

export interface PhraseOccurrence {
  entryId: string;
  dateKey: string;
  dateLabel: string;
  snippet: string;
  mood: string;
  intensity: number;
}

export interface PhraseMemoryRecord {
  phrase: string;
  category: PhraseCategory;
  count: number;
  firstSeen: string;
  lastSeen: string;
  firstSeenLabel: string;
  lastSeenLabel: string;
  entryIds: string[];
  occurrences: PhraseOccurrence[];
  avgIntensity: number;
  dominantMood: string | null;
}

const LINGUISTIC_HABITS: Array<{ pattern: RegExp; label: string }> = [
  { pattern: /\bi should\b/gi, label: "I should" },
  { pattern: /\bi have to\b/gi, label: "I have to" },
  { pattern: /\bmaybe\b/gi, label: "maybe" },
  { pattern: /\beventually\b/gi, label: "eventually" },
  { pattern: /\bi don'?t know\b/gi, label: "I don't know" },
  { pattern: /\bonce things settle\b/gi, label: "once things settle" },
  { pattern: /\bi just need\b/gi, label: "I just need" },
  { pattern: /\bi guess\b/gi, label: "I guess" },
  { pattern: /\bi need to\b/gi, label: "I need to" },
  { pattern: /\bi keep\b/gi, label: "I keep" },
];

const SELF_LABEL_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
  { pattern: /\bi'?m always\b/gi, label: "I'm always" },
  { pattern: /\bi am always\b/gi, label: "I am always" },
  { pattern: /\bi'?m such a\b/gi, label: "I'm such a" },
  { pattern: /\bi'?m the kind of\b/gi, label: "I'm the kind of" },
  { pattern: /\bi'?m just\b/gi, label: "I'm just" },
  { pattern: /\bi'?m not the type\b/gi, label: "I'm not the type" },
];

const METAPHOR_HINTS = [
  "weight on",
  "knot in",
  "tighten",
  "spiral",
  "loop",
  "carrying",
  "drift",
  "wave",
  "cloud",
  "fog",
  "anchor",
  "thread",
  "heavy",
  "drowning",
  "stuck",
];

interface MutableRecord {
  phrase: string;
  category: PhraseCategory;
  count: number;
  firstSeen: string;
  lastSeen: string;
  entryIds: Set<string>;
  occurrences: PhraseOccurrence[];
  moodCounts: Map<string, number>;
  intensitySum: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function extractSnippet(text: string, index: number, length: number): string {
  const start = Math.max(0, index - 40);
  const end = Math.min(text.length, index + length + 40);
  let snippet = text.slice(start, end).trim();
  if (start > 0) snippet = `…${snippet}`;
  if (end < text.length) snippet = `${snippet}…`;
  return snippet.slice(0, 160);
}

function addOccurrence(
  record: MutableRecord,
  entry: JournalEntry,
  matchIndex: number,
  matchLength: number,
  transcript: string,
): void {
  const createdAt = entry.createdAt;
  record.count += 1;
  record.entryIds.add(entry.id);

  if (createdAt < record.firstSeen) record.firstSeen = createdAt;
  if (createdAt > record.lastSeen) record.lastSeen = createdAt;

  const mood = entry.reflection.mood.toLowerCase();
  record.moodCounts.set(mood, (record.moodCounts.get(mood) ?? 0) + 1);
  record.intensitySum += entry.reflection.emotionalIntensity;

  record.occurrences.push({
    entryId: entry.id,
    dateKey: toDayKey(createdAt),
    dateLabel: formatEntryDate(createdAt),
    snippet: extractSnippet(transcript, matchIndex, matchLength),
    mood: entry.reflection.mood,
    intensity: entry.reflection.emotionalIntensity,
  });
}

function scanPattern(
  store: Map<string, MutableRecord>,
  entries: JournalEntry[],
  pattern: RegExp,
  label: string,
  category: PhraseCategory,
): void {
  const key = `${category}:${label.toLowerCase()}`;
  const re = new RegExp(pattern.source, pattern.flags);

  for (const entry of entries) {
    const transcript = transcriptForPhraseScanning(entry);
    let match: RegExpExecArray | null;
    re.lastIndex = 0;

    while ((match = re.exec(transcript)) !== null) {
      const record =
        store.get(key) ??
        ({
          phrase: label,
          category,
          count: 0,
          firstSeen: entry.createdAt,
          lastSeen: entry.createdAt,
          entryIds: new Set<string>(),
          occurrences: [],
          moodCounts: new Map<string, number>(),
          intensitySum: 0,
        } satisfies MutableRecord);

      addOccurrence(record, entry, match.index, match[0].length, transcript);
      store.set(key, record);
    }
  }
}

function extractNgrams(text: string, n: number): Array<{ ngram: string; index: number }> {
  const lower = text.toLowerCase();
  const words = lower.replace(/[^\w\s']/g, " ").split(/\s+/).filter((w) => w.length > 2);
  const results: Array<{ ngram: string; index: number }> = [];

  for (let i = 0; i <= words.length - n; i += 1) {
    const ngram = words.slice(i, i + n).join(" ");
    const index = lower.indexOf(ngram);
    if (index >= 0) results.push({ ngram, index });
  }

  return results;
}

function finalize(store: Map<string, MutableRecord>): PhraseMemoryRecord[] {
  const results: PhraseMemoryRecord[] = [];

  for (const record of store.values()) {
    if (record.count < 2 && record.entryIds.size < 2) continue;

    const dominantMood =
      [...record.moodCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

    results.push({
      phrase: record.phrase,
      category: record.category,
      count: record.count,
      firstSeen: record.firstSeen,
      lastSeen: record.lastSeen,
      firstSeenLabel: formatEntryDate(record.firstSeen),
      lastSeenLabel: formatEntryDate(record.lastSeen),
      entryIds: [...record.entryIds],
      occurrences: record.occurrences.slice(-6),
      avgIntensity:
        record.count > 0
          ? Math.round((record.intensitySum / record.count) * 10) / 10
          : 0,
      dominantMood,
    });
  }

  return results.sort(
    (a, b) => b.count - a.count || b.entryIds.length - a.entryIds.length,
  );
}

function scanMetaphorsAndFraming(
  store: Map<string, MutableRecord>,
  entries: JournalEntry[],
): void {
  for (const entry of entries) {
    const transcript = transcriptForPhraseScanning(entry);
    const lower = transcript.toLowerCase();

    for (const hint of METAPHOR_HINTS) {
      let index = lower.indexOf(hint);
      while (index >= 0) {
        const key = `metaphor:${hint}`;
        const record =
          store.get(key) ??
          ({
            phrase: hint,
            category: "metaphor" as const,
            count: 0,
            firstSeen: entry.createdAt,
            lastSeen: entry.createdAt,
            entryIds: new Set<string>(),
            occurrences: [],
            moodCounts: new Map<string, number>(),
            intensitySum: 0,
          } satisfies MutableRecord);

        addOccurrence(record, entry, index, hint.length, transcript);
        store.set(key, record);
        index = lower.indexOf(hint, index + hint.length);
      }
    }

    for (const n of [3, 4]) {
      for (const { ngram, index } of extractNgrams(transcript, n)) {
        if (ngram.split(" ").some((w) => w.length < 3)) continue;
        const isMetaphor = METAPHOR_HINTS.some((h) => ngram.includes(h));
        const category: PhraseCategory = isMetaphor ? "metaphor" : "framing";
        const key = `${category}:${ngram}`;

        const record =
          store.get(key) ??
          ({
            phrase: ngram,
            category,
            count: 0,
            firstSeen: entry.createdAt,
            lastSeen: entry.createdAt,
            entryIds: new Set<string>(),
            occurrences: [],
            moodCounts: new Map<string, number>(),
            intensitySum: 0,
          } satisfies MutableRecord);

        addOccurrence(record, entry, index, ngram.length, transcript);
        store.set(key, record);
      }
    }
  }
}

function buildPhraseMemoryUncached(entries: JournalEntry[]): PhraseMemoryRecord[] {
  if (entries.length === 0) return [];

  const sorted = sortedEntries(entries);
  const store = new Map<string, MutableRecord>();

  for (const habit of LINGUISTIC_HABITS) {
    scanPattern(store, sorted, habit.pattern, habit.label, "linguistic_habit");
  }

  for (const label of SELF_LABEL_PATTERNS) {
    scanPattern(store, sorted, label.pattern, label.label, "self_label");
  }

  scanMetaphorsAndFraming(store, sorted);

  return finalize(store).slice(0, 20);
}

/** Build phrase memory across all entries (cached by archive fingerprint). */
export function buildPhraseMemory(entries: JournalEntry[]): PhraseMemoryRecord[] {
  return getCachedPhraseMemory(entries, buildPhraseMemoryUncached);
}

/** Phrases linked to a specific entry. */
export function getPhrasesForEntry(
  entries: JournalEntry[],
  entryId: string,
): PhraseMemoryRecord[] {
  return buildPhraseMemory(entries)
    .filter((p) => p.entryIds.includes(entryId))
    .map((p) => ({
      ...p,
      occurrences: p.occurrences.filter((o) => o.entryId === entryId),
    }));
}

/** Top repeated phrases for archive-wide views. */
export function getTopPhrases(
  entries: JournalEntry[],
  limit = 10,
): PhraseMemoryRecord[] {
  return buildPhraseMemory(entries).slice(0, limit);
}

/** Adapter for legacy pattern-insights shape. */
export function toLegacyRepeatedPhraseMatch(
  record: PhraseMemoryRecord,
): {
  phrase: string;
  count: number;
  entryCount: number;
  example: string;
  category: "linguistic_habit" | "metaphor" | "framing";
} {
  return {
    phrase: record.phrase,
    count: record.count,
    entryCount: record.entryIds.length,
    example: record.occurrences[0]?.snippet ?? `"${record.phrase}"`,
    category:
      record.category === "self_label" ? "framing" : record.category,
  };
}
