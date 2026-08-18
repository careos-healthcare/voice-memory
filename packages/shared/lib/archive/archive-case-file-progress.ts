import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveCaseFileProgressView {
  title: string;
  evidenceCount: number;
  evidenceLabel: string;
  areasLabel: string | null;
  beliefsUnderReview: number;
  beliefsStrengthened: number;
  beliefsChallenged: number;
}

function formatAreas(areas: string[]): string | null {
  if (areas.length === 0) return null;
  const labels = areas.slice(0, 4).map((a) => a);
  if (labels.length === 1) return labels[0]!;
  if (labels.length === 2) return `${labels[0]} + ${labels[1]}`;
  return `${labels.slice(0, -1).join(" + ")} + ${labels[labels.length - 1]}`;
}

export function buildArchiveCaseFileProgressView(
  entriesInput?: JournalEntry[],
): ArchiveCaseFileProgressView | null {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  if (entries.length < 1) return null;

  const stats = buildEvidenceArchiveStats(entries);
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });

  const entryIds = entries.map((e) => e.id);
  const areas = linkedAreasForEntries(entries, entryIds);

  let underReview = 0;
  let strengthened = 0;
  let challenged = 0;

  for (const theory of report.all) {
    if (theory.status === "strengthening") strengthened += 1;
    else if (theory.status === "weakening") challenged += 1;
    else if (theory.status === "active") underReview += 1;
  }

  if (underReview === 0 && report.all.length > 0) underReview = 1;

  return {
    title: "Archive case file",
    evidenceCount: stats.reflectionCount,
    evidenceLabel: `${stats.reflectionCount} observation${stats.reflectionCount === 1 ? "" : "s"}`,
    areasLabel: formatAreas(areas),
    beliefsUnderReview: underReview,
    beliefsStrengthened: strengthened,
    beliefsChallenged: challenged,
  };
}
