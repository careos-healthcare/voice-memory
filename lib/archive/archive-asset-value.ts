import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveAssetValueView {
  totalReflections: number;
  daysCovered: number;
  monthsCovered: number;
  recurringBeliefsTracked: number;
  evidenceQuotesStored: number;
  beliefChangesRecorded: number;
  firstReflectionDate: string | null;
  firstReflectionLabel: string | null;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function formatFirstDate(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
  }).format(new Date(iso));
}

export function buildArchiveAssetValueView(
  entriesInput?: JournalEntry[],
): ArchiveAssetValueView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length === 0) return null;

  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const first = sorted[0]!;
  const last = sorted[sorted.length - 1]!;
  const firstKey = toDayKey(first.createdAt);
  const lastKey = toDayKey(last.createdAt);
  const daysCovered = Math.max(1, daysBetweenKeys(firstKey, lastKey) + 1);
  const monthsCovered = new Set(
    sorted.map((e) => {
      const d = new Date(e.createdAt);
      return `${d.getFullYear()}-${d.getMonth()}`;
    }),
  ).size;

  const report =
    entries.length >= 2
      ? buildTheoryTrackerReport(entries, { persistSnapshots: false })
      : null;
  const recurringBeliefsTracked = report
    ? report.active.length + report.strengthening.length + report.weakening.length
    : 0;

  let evidenceQuotesStored = 0;
  let beliefChangesRecorded = 0;
  if (report) {
    for (const theory of report.all) {
      evidenceQuotesStored += theory.supportingEvidence.length + theory.contradictingEvidence.length;
      beliefChangesRecorded += readBeliefTimelineHistory(theory.id).length;
      beliefChangesRecorded += theory.whatChanged?.length ?? 0;
    }
  }

  return {
    totalReflections: entries.length,
    daysCovered,
    monthsCovered,
    recurringBeliefsTracked,
    evidenceQuotesStored,
    beliefChangesRecorded,
    firstReflectionDate: first.createdAt,
    firstReflectionLabel: formatFirstDate(first.createdAt),
  };
}
