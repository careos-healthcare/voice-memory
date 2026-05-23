import type { JournalEntry } from "@/types/journal";
import type { RepeatedPhraseMatch } from "@/types/pattern-insights";

const LINGUISTIC_HABITS: Array<{ pattern: RegExp; label: string }> = [
  { pattern: /\bi should\b/gi, label: "I should" },
  { pattern: /\bi have to\b/gi, label: "I have to" },
  { pattern: /\bmaybe\b/gi, label: "maybe" },
  { pattern: /\beventually\b/gi, label: "eventually" },
  { pattern: /\bi don'?t know\b/gi, label: "I don't know" },
  { pattern: /\bi guess\b/gi, label: "I guess" },
  { pattern: /\bi need to\b/gi, label: "I need to" },
  { pattern: /\bi keep\b/gi, label: "I keep" },
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
];

function countMatches(text: string, pattern: RegExp): number {
  return (text.match(pattern) ?? []).length;
}

function extractRepeatedNgrams(text: string, n: number): string[] {
  const words = text
    .toLowerCase()
    .replace(/[^\w\s']/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2);
  const ngrams: string[] = [];
  for (let i = 0; i <= words.length - n; i += 1) {
    ngrams.push(words.slice(i, i + n).join(" "));
  }
  return ngrams;
}

export function detectRepeatedPhrases(
  entries: JournalEntry[],
  currentEntryId: string,
): RepeatedPhraseMatch[] {
  const current = entries.find((e) => e.id === currentEntryId);
  if (!current) return [];

  const results: RepeatedPhraseMatch[] = [];
  const allText = entries.map((e) => ({
    id: e.id,
    text: `${e.transcript} ${e.reflection.exactLanguagePattern ?? ""}`.toLowerCase(),
  }));

  for (const habit of LINGUISTIC_HABITS) {
    let totalCount = 0;
    let entryHits = 0;
    let example = "";

    for (const row of allText) {
      const hits = countMatches(row.text, habit.pattern);
      if (hits > 0) {
        totalCount += hits;
        entryHits += 1;
        if (!example) {
          const match = row.text.match(habit.pattern);
          example = match ? `"${match[0]}"` : habit.label;
        }
      }
    }

    if (totalCount >= 2 && entryHits >= 1) {
      const inCurrent = countMatches(current.transcript.toLowerCase(), habit.pattern);
      if (inCurrent > 0 || entryHits >= 2) {
        results.push({
          phrase: habit.label,
          count: totalCount,
          entryCount: entryHits,
          example,
          category: "linguistic_habit",
        });
      }
    }
  }

  const ngramCounts = new Map<string, { count: number; entryIds: Set<string>; example: string }>();

  for (const row of allText) {
    for (const n of [3, 4]) {
      for (const ngram of extractRepeatedNgrams(row.text, n)) {
        if (ngram.split(" ").some((w) => w.length < 3)) continue;
        const existing = ngramCounts.get(ngram) ?? {
          count: 0,
          entryIds: new Set<string>(),
          example: ngram,
        };
        existing.count += 1;
        existing.entryIds.add(row.id);
        ngramCounts.set(ngram, existing);
      }
    }
  }

  for (const [ngram, data] of ngramCounts.entries()) {
    if (data.entryIds.size >= 2 && data.count >= 2) {
      const isMetaphor = METAPHOR_HINTS.some((hint) => ngram.includes(hint));
      results.push({
        phrase: ngram,
        count: data.count,
        entryCount: data.entryIds.size,
        example: `"${data.example}"`,
        category: isMetaphor ? "metaphor" : "framing",
      });
    }
  }

  return results
    .sort((a, b) => b.entryCount - b.entryCount || b.count - a.count)
    .slice(0, 8);
}
