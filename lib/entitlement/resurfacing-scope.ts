import type { JournalEntry } from "@/types/journal";

/** Complete user-owned entry pool for memory / resurfacing builders. */
export function entriesForResurfacingScope(
  allEligible: JournalEntry[],
): JournalEntry[] {
  return [...allEligible].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
}
