import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveProductObject } from "@/types/archive-product-model";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function archiveAgeDays(entries: JournalEntry[]): number {
  const list = eligible(entries);
  if (list.length === 0) return 0;
  const sorted = [...list].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  return Math.max(
    1,
    daysBetweenKeys(toDayKey(sorted[0]!.createdAt), todayKey()) + 1,
  );
}

/** Single product read model — The Archive (no new analysis). */
export function buildArchiveProductObject(
  entriesInput?: JournalEntry[],
): ArchiveProductObject | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length === 0) return null;

  const belief = buildArchiveBeliefView(entries);
  const stats = buildEvidenceArchiveStats(entries);
  const locker = buildEvidenceLocker(entries);

  const changesCount = belief
    ? Math.max(
        belief.changeLines.length,
        readBeliefTimelineHistory(belief.theoryId).length,
      )
    : stats.beliefChangesRecorded;

  const evidenceCount = Math.max(stats.evidenceQuotesStored, locker.items.length);

  return {
    currentBelief: belief?.belief ?? "Your archive is still gathering evidence.",
    confidence: belief?.confidence ?? 0,
    status: belief?.statusLabel ?? "Building",
    evidenceCount,
    changesCount,
    archiveAgeDays: stats.daysCovered ?? archiveAgeDays(entries),
  };
}
