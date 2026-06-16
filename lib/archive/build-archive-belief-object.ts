import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { buildWhyArchiveTrustsThisLines } from "@/lib/archive/archive-reputation-trust";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { toArchiveEmotionalCopy } from "@/lib/archive/archive-emotional-copy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveBeliefObject } from "@/types/archive-belief-object";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

/** Single source of truth — every major archive surface should consume this. */
export function buildArchiveBeliefObject(
  entriesInput?: JournalEntry[],
): ArchiveBeliefObject | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length === 0) return null;

  const belief = buildArchiveBeliefView(entries);
  const reputation = buildArchiveReputationView(entries);
  const stats = buildEvidenceArchiveStats(entries);
  const locker = buildEvidenceLocker(entries);
  const trustReasons = buildWhyArchiveTrustsThisLines(entries);

  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  const lastUpdated = sorted[0]?.createdAt ?? new Date().toISOString();

  const whatChanged = belief
    ? belief.changeLines.map((line) => toArchiveEmotionalCopy(line.text.replace(/^\+\s*/, "")))
    : [];

  const timelinePoints = belief
    ? readBeliefTimelineHistory(belief.theoryId).length
    : 0;

  return {
    belief: belief?.belief ?? "Your archive is still gathering evidence.",
    confidence: belief?.confidence ?? 0,
    status: belief?.statusLabel ?? "Building",
    reputation: reputation?.summary ?? "The archive is still learning.",
    evidenceCount: Math.max(stats.evidenceQuotesStored, locker.items.length),
    lifeAreas: belief?.evidence.lifeAreas ?? [],
    whatChanged,
    trustReasons,
    timelinePoints,
    lastUpdated,
  };
}
