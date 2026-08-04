import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildWhyArchiveTrustsThisLines } from "@/lib/archive/archive-reputation-trust";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { toArchiveEmotionalCopy } from "@/lib/archive/archive-emotional-copy";
import { resolveArchiveHealthV3 } from "@/lib/archive/archive-health-v3";
import { buildArchiveWatchItemV3 } from "@/lib/archive/archive-watch-v3";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveStateObject } from "@/types/archive-state-object";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function summarizeEvidence(lines: string[], evidenceCount: number): string {
  if (lines.length > 0) {
    return lines[0]!;
  }
  if (evidenceCount > 0) {
    return `The archive is weighing ${evidenceCount} evidence item${evidenceCount === 1 ? "" : "s"} from your saved words.`;
  }
  return "Save more moments so the archive can explain why it believes this.";
}

function summarizeChange(changeLines: string[]): string {
  if (changeLines.length === 0) {
    return "Nothing notable has shifted since your last visit.";
  }
  const first = changeLines[0]!;
  if (changeLines.length === 1) return first;
  return `${first} ${changeLines.length > 1 ? `(${changeLines.length - 1} more shift${changeLines.length === 2 ? "" : "s"} recorded.)` : ""}`.trim();
}

/**
 * Archive Reduction v3 — collapse internal systems into one understandable object.
 * Maturity, ownership, reputation, survival, and accuracy feed this builder only.
 */
export function buildArchiveStateObject(
  entriesInput?: JournalEntry[],
): ArchiveStateObject | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length === 0) return null;

  const beliefView = buildArchiveBeliefView(entries);
  const trustLines = buildWhyArchiveTrustsThisLines(entries);
  const stats = buildEvidenceArchiveStats(entries);
  const locker = buildEvidenceLocker(entries);
  const evidenceCount = Math.max(stats.evidenceQuotesStored, locker.items.length);

  const changeLines = beliefView
    ? beliefView.changeLines.map((line) =>
        toArchiveEmotionalCopy(line.text.replace(/^\+\s*/, "")),
      )
    : [];

  return {
    belief: beliefView?.belief ?? "Your archive is still gathering evidence.",
    confidence: beliefView?.confidence ?? 0,
    evidenceSummary: summarizeEvidence(trustLines, evidenceCount),
    changeSummary: summarizeChange(changeLines),
    watchItem: buildArchiveWatchItemV3(entries),
    health: resolveArchiveHealthV3(entries),
  };
}
