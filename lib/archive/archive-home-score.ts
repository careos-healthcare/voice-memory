import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { ARCHIVE_BELIEF_STATUS_LABEL } from "@/lib/archive/archive-belief-copy";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { ARCHIVE_REPUTATION_LEVEL_LABEL } from "@/lib/archive/archive-reputation-copy";
import { buildSessionMovementSummary } from "@/lib/archive/session-movement-summary";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveHomeScoreView {
  currentBelief: string;
  reputationLabel: string;
  daysTracked: number;
  evidenceCount: number;
  statusLabel: string;
  whatChangedOneLine: string;
}

function whatChangedLine(entries: JournalEntry[]): string {
  const movement = buildSessionMovementSummary(entries, { browseSurface: true });
  if (movement?.headline) return movement.headline;
  const belief = buildArchiveBeliefView(entries);
  const firstChange = belief?.changeLines[0]?.text.replace(/^\+\s*/, "").trim();
  if (firstChange) return firstChange;
  return "Your archive is gathering comparison points.";
}

export function buildArchiveHomeScoreView(
  entriesInput?: JournalEntry[],
): ArchiveHomeScoreView | null {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const belief = buildArchiveBeliefView(entries);
  const stats = buildEvidenceArchiveStats(entries);
  const reputation = buildArchiveReputationView(entries);

  if (!belief && entries.length === 0) return null;

  return {
    currentBelief: belief?.belief ?? "Still forming — a few more saved moments help.",
    reputationLabel: reputation
      ? ARCHIVE_REPUTATION_LEVEL_LABEL[reputation.level]
      : "Developing",
    daysTracked: reputation?.daysTracked ?? stats.daysCovered ?? 0,
    evidenceCount: stats.reflectionCount,
    statusLabel: belief
      ? ARCHIVE_BELIEF_STATUS_LABEL[belief.status]
      : "Under review",
    whatChangedOneLine: whatChangedLine(entries),
  };
}
