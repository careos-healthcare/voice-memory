import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveAccuracyView } from "@/lib/archive/archive-accuracy";
import { buildContradictionHistoryView } from "@/lib/archive/contradiction-history";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { ARCHIVE_REPUTATION_SUMMARY } from "@/lib/archive/archive-reputation-copy";
import { buildDivergedPredictionEntryIds } from "@/lib/blind-spots/evidence-accuracy";
import { assertNoCertaintyLanguage } from "@/lib/theories/theory-confidence-movement";
import { assessArchiveAttachment } from "@/lib/retention/archive-attachment-signals";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveReputationLevel,
  ArchiveReputationView,
} from "@/types/archive-reputation";
import type { JournalEntry } from "@/types/journal";

const LEVEL_RANK: Record<ArchiveReputationLevel, number> = {
  low: 0,
  developing: 1,
  moderate: 2,
  high: 3,
  very_high: 4,
};

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function scoreToLevel(score: number): ArchiveReputationLevel {
  if (score < 18) return "low";
  if (score < 36) return "developing";
  if (score < 54) return "moderate";
  if (score < 72) return "high";
  return "very_high";
}

export function archiveReputationLevelRank(level: ArchiveReputationLevel): number {
  return LEVEL_RANK[level];
}

export function buildArchiveReputationView(
  entriesInput?: JournalEntry[],
): ArchiveReputationView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const survival = buildBeliefSurvivalView(entries);
  const accuracy = buildArchiveAccuracyView(entries);
  const stats = buildEvidenceArchiveStats(entries);
  const locker = buildEvidenceLocker(entries);
  const contradiction = buildContradictionHistoryView(entries);
  const attachment = assessArchiveAttachment(entries);

  const supportingReflections = survival?.reflectionsSupporting ?? stats.reflectionCount;
  const lifeAreas = belief.evidence.lifeAreas.length;
  const contradictionsSurvived = survival?.contradictionsSurvived ?? 0;
  const daysTracked = survival?.daysAlive ?? stats.daysCovered ?? 1;
  const timelineChanges = readBeliefTimelineHistory(belief.theoryId).length;
  const beliefChangesObserved = Math.max(
    stats.beliefChangesRecorded,
    timelineChanges,
    belief.changeLines.length,
    contradiction ? 1 : 0,
  );

  const leadAccuracy = accuracy?.beliefs.find((row) => row.theoryId === belief.theoryId);
  const accuracySignals =
    accuracy?.beliefs.filter((row) => row.status === "confirmed").length ?? 0;

  const crossAreaBonus = lifeAreas >= 2 ? 14 : lifeAreas >= 1 ? 6 : 0;
  const costBonus = belief.evidence.costEvidenceLines.length > 0 ? 6 : 0;
  const lockerBonus = Math.min(locker.items.length, 8);
  const failedPredictionBonus = buildDivergedPredictionEntryIds(entries).size > 0 ? 4 : 0;
  const attachmentBonus = Math.min(Math.floor(attachment.score / 12), 10);
  const challengedPenalty = leadAccuracy?.status === "challenged" ? 8 : 0;

  let score = 0;
  score += Math.min(supportingReflections * 3, 24);
  score += crossAreaBonus;
  score += Math.min(contradictionsSurvived * 4, 16);
  score += Math.min(Math.floor(daysTracked / 7) * 2, 14);
  score += Math.min(beliefChangesObserved * 2, 10);
  score += accuracySignals * 8;
  score += lockerBonus;
  score += costBonus;
  score += failedPredictionBonus;
  score += attachmentBonus;
  score -= challengedPenalty;
  score = Math.max(0, Math.min(100, score));

  const level = scoreToLevel(score);
  const summary = ARCHIVE_REPUTATION_SUMMARY[level];
  assertNoCertaintyLanguage(summary);

  return {
    level,
    supportingReflections,
    lifeAreas,
    contradictionsSurvived,
    daysTracked,
    beliefChangesObserved,
    accuracySignals,
    summary,
    meterFill: score,
  };
}
