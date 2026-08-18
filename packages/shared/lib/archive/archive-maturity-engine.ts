import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import {
  ARCHIVE_MATURITY_STAGE_LABEL,
} from "@/lib/archive/archive-maturity-copy";
import {
  ARCHIVE_PROGRESS_HEADLINE,
  nextMilestoneForScore,
} from "@/lib/archive/archive-progress-copy";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveMaturityStage } from "@/types/archive-maturity";
import type {
  ArchiveMaturityEngineInput,
  ArchiveProgressView,
} from "@/types/archive-progress";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function timelineAgeDays(entries: JournalEntry[]): number {
  if (entries.length === 0) return 0;
  if (entries.length === 1) return 1;
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const first = toDayKey(sorted[0]!.createdAt);
  const last = toDayKey(sorted[sorted.length - 1]!.createdAt);
  return Math.max(1, daysBetweenKeys(first, last) + 1);
}

function beliefChangeCount(entries: JournalEntry[], theoryIds: string[]): number {
  let total = 0;
  for (const id of theoryIds) {
    total += readBeliefTimelineHistory(id).length;
  }
  if (total > 0) return total;
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  return report.all.filter((t) => (t.whatChanged?.length ?? 0) > 0).length;
}

function stageFromSignals(signals: {
  reflectionCount: number;
  beliefCount: number;
  beliefChanges: number;
  score: number;
}): ArchiveMaturityStage {
  const { reflectionCount, beliefCount, beliefChanges, score } = signals;
  if (reflectionCount <= 1) return "starting";
  if (reflectionCount <= 3 && beliefCount === 0) return "building_evidence";
  if (beliefCount === 0) return "building_evidence";
  if (beliefChanges >= 2 || score >= 72) return "mature_archive";
  if (beliefChanges >= 1 || score >= 48) return "beliefs_changing";
  return "beliefs_forming";
}

/** Unified archive maturity score from five signals (0–100). */
export class ArchiveMaturityEngine {
  static compute(input: ArchiveMaturityEngineInput): number {
    const raw =
      Math.min(input.reflectionCount, 15) * 3.2 +
      Math.min(input.beliefCount, 8) * 5.5 +
      Math.min(input.beliefChanges, 12) * 4 +
      Math.min(input.reputationScore, 100) * 0.28 +
      Math.min(input.timelineAgeDays, 120) * 0.12;

    return Math.min(100, Math.max(0, Math.round(raw)));
  }

  static buildView(input: ArchiveMaturityEngineInput): ArchiveProgressView {
    const score = ArchiveMaturityEngine.compute(input);
    const stage = stageFromSignals({
      reflectionCount: input.reflectionCount,
      beliefCount: input.beliefCount,
      beliefChanges: input.beliefChanges,
      score,
    });
    const milestone = nextMilestoneForScore(score);

    return {
      score,
      stage,
      stageLabel: ARCHIVE_MATURITY_STAGE_LABEL[stage],
      headline: ARCHIVE_PROGRESS_HEADLINE,
      nextMilestoneLabel: milestone.label,
      nextMilestonePercent: milestone.percent,
    };
  }
}

export function buildArchiveMaturityEngineInput(
  entriesInput?: JournalEntry[],
): ArchiveMaturityEngineInput {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const snapshot = buildArchiveValueSnapshot(entries);
  const report =
    entries.length >= 2
      ? buildTheoryTrackerReport(entries, { persistSnapshots: false })
      : null;

  const beliefCount =
    (report?.active.length ?? 0) + (report?.strengthening.length ?? 0);
  const theoryIds = report?.all.map((t) => t.id) ?? [];
  const reputation = buildArchiveReputationView(entries);

  return {
    reflectionCount: snapshot.reflectionCount,
    beliefCount,
    beliefChanges: beliefChangeCount(entries, theoryIds),
    reputationScore: reputation?.meterFill ?? 0,
    timelineAgeDays: timelineAgeDays(entries),
  };
}

export function buildArchiveProgressView(
  entriesInput?: JournalEntry[],
): ArchiveProgressView {
  return ArchiveMaturityEngine.buildView(buildArchiveMaturityEngineInput(entriesInput));
}
