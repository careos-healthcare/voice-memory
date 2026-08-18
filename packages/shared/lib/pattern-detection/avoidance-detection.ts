import type { JournalEntry } from "@/types/journal";
import type { AvoidanceSignal as LegacyAvoidanceSignal } from "@/types/pattern-insights";

import { detectAvoidanceSignalsForEntry } from "@/lib/patterns/avoidance";

/** @deprecated Use lib/patterns/avoidance.ts directly */
export function detectAvoidanceSignals(
  entry: JournalEntry,
  allEntries?: JournalEntry[],
): LegacyAvoidanceSignal[] {
  if (!allEntries?.length) return [];
  return detectAvoidanceSignalsForEntry(allEntries, entry.id);
}
