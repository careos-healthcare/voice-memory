import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface EvidenceArchiveStats {
  reflectionCount: number;
  daysCovered: number | null;
  beliefsTracked: number;
  beliefChangesRecorded: number;
  evidenceQuotesStored: number;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

export function buildEvidenceArchiveStats(
  entriesInput?: JournalEntry[],
): EvidenceArchiveStats {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const reflectionCount = entries.length;

  let daysCovered: number | null = null;
  if (entries.length >= 1) {
    const sorted = [...entries].sort(
      (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
    );
    daysCovered = Math.max(
      1,
      daysBetweenKeys(toDayKey(sorted[0]!.createdAt), todayKey()) + 1,
    );
  }

  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const beliefsTracked = report.all.length;

  const belief = buildArchiveBeliefView(entries);
  let beliefChangesRecorded = 0;
  if (belief) {
    beliefChangesRecorded = Math.max(
      belief.changeLines.length,
      readBeliefTimelineHistory(belief.theoryId).length,
    );
  }

  let evidenceQuotesStored = 0;
  for (const theory of report.all) {
    evidenceQuotesStored +=
      theory.supportingEvidence.length + theory.contradictingEvidence.length;
  }

  return {
    reflectionCount,
    daysCovered,
    beliefsTracked,
    beliefChangesRecorded,
    evidenceQuotesStored,
  };
}
