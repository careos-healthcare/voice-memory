import { FREE_ARCHIVE_LIMIT } from "@/lib/entitlement/entitlements";
import { hasEntitlement } from "@/lib/entitlement/entitlements";
import type { JournalEntry } from "@/types/journal";

/** Plan-aware entry pool for memory / resurfacing builders. */
export function entriesForResurfacingScope(
  allEligible: JournalEntry[],
): JournalEntry[] {
  if (hasEntitlement("deeper_resurfacing") || hasEntitlement("unlimited_archive")) {
    return allEligible;
  }
  const sorted = [...allEligible].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  return sorted.slice(0, FREE_ARCHIVE_LIMIT);
}
