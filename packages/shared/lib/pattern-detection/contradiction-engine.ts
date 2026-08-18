import type { JournalEntry } from "@/types/journal";
import type { ContradictionMatch } from "@/types/pattern-insights";

import {
  detectContradictionsForEntry,
  toLegacyContradictionMatch,
} from "@/lib/patterns/contradictions";

/** @deprecated Use lib/patterns/contradictions.ts directly */
export function detectContradictions(
  entries: JournalEntry[],
  currentEntryId: string,
): ContradictionMatch[] {
  return detectContradictionsForEntry(entries, currentEntryId).map(toLegacyContradictionMatch);
}
