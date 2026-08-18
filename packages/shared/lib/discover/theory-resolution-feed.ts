import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import type { TheoryResolutionFeedReport } from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

/** Theories that may no longer fit — for the discover resolved section. */
export function buildTheoryResolutionFeed(
  entries: JournalEntry[],
): TheoryResolutionFeedReport {
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: true });
  const resolved = report.resolved;
  const retired = report.retired;

  return {
    generatedAt: new Date().toISOString(),
    resolved,
    retired,
    total: resolved.length + retired.length,
  };
}
