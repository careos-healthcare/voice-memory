import type { JournalEntry } from "@/types/journal";
import type { EmotionalEvolutionSignal } from "@/types/pattern-insights";

import { detectEmotionalEvolutionForEntry } from "@/lib/patterns/emotional-evolution";

/** @deprecated Use lib/patterns/emotional-evolution.ts directly */
export function detectEmotionalEvolution(
  entries: JournalEntry[],
  currentEntryId: string,
): EmotionalEvolutionSignal[] {
  return detectEmotionalEvolutionForEntry(entries, currentEntryId);
}
