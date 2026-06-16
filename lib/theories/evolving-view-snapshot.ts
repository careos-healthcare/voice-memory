import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import type { JournalEntry } from "@/types/journal";

export interface EvolvingViewSnapshot {
  totalTheories: number;
  underReviewCount: number;
  strengtheningCount: number;
  weakeningOrResolvedCount: number;
  lastUpdated: string | null;
}

export function buildEvolvingViewSnapshot(
  entries: JournalEntry[],
): EvolvingViewSnapshot {
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const underReviewCount = report.active.length;
  const strengtheningCount = report.strengthening.length;
  const weakeningOrResolvedCount =
    report.weakening.length + report.resolved.length + report.retired.length;

  return {
    totalTheories: report.all.length,
    underReviewCount,
    strengtheningCount,
    weakeningOrResolvedCount,
    lastUpdated: report.generatedAt,
  };
}
