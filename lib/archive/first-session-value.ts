import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface FirstSessionValueView {
  evidenceAdded: number;
  observationCount: number;
  observationLabel: string;
  nextMilestone: string;
}

export function buildFirstSessionValueView(
  entriesInput?: JournalEntry[],
): FirstSessionValueView | null {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const count = entries.length;
  if (count !== 1) return null;

  return {
    evidenceAdded: 1,
    observationCount: 1,
    observationLabel: count === 1 ? "1 observation" : `${count} observations`,
    nextMilestone: "Evidence begins connecting after a few reflections.",
  };
}
