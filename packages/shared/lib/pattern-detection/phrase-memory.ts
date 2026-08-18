import type { JournalEntry } from "@/types/journal";
import type { RepeatedPhraseMatch } from "@/types/pattern-insights";

import {
  getPhrasesForEntry,
  toLegacyRepeatedPhraseMatch,
} from "@/lib/patterns/phrase-memory";

/** @deprecated Use lib/patterns/phrase-memory.ts directly */
export function detectRepeatedPhrases(
  entries: JournalEntry[],
  currentEntryId: string,
): RepeatedPhraseMatch[] {
  return getPhrasesForEntry(entries, currentEntryId)
    .map(toLegacyRepeatedPhraseMatch)
    .slice(0, 8);
}
