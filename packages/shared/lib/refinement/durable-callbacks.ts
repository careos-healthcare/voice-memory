import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { DurableCallbacksReport, DurableCallbackRow } from "@/types/memory-compounding";

const NOVELTY_PAUSE_THRESHOLD = 55;
const DURABLE_MIN_REVISITS = 2;
const DURABLE_MIN_RESIDUE = 40;

function collectLoopMetrics(report: ReturnType<typeof buildLoopOptimizationReport>): import("@/lib/retention/loop-optimization").CallbackLoopMetrics[] {
  const merged = [
    ...report.topPerforming,
    ...report.causingRevisits,
    ...report.causingReflections,
    ...report.causingBookmarks,
    ...report.topCopied,
    ...report.deadCallbacks,
  ];
  const seen = new Set<string>();
  return merged.filter((row) => {
    if (seen.has(row.noteId)) return false;
    seen.add(row.noteId);
    return true;
  });
}

function rowFromMetrics(input: {
  id: string;
  text: string;
  revisits: number;
  copies: number;
  reflections: number;
  residueScore: number;
  pauseScore: number;
  dead: boolean;
  halfLifeScore?: number;
}): DurableCallbackRow {
  const survivesNovelty =
    input.revisits >= DURABLE_MIN_REVISITS ||
    input.copies >= 1 ||
    input.reflections >= 1 ||
    (input.halfLifeScore !== undefined && input.halfLifeScore >= 45 && input.residueScore >= DURABLE_MIN_RESIDUE);

  const noveltyOnly =
    input.pauseScore >= NOVELTY_PAUSE_THRESHOLD &&
    input.revisits === 0 &&
    input.copies === 0 &&
    input.reflections === 0 &&
    input.residueScore < 30;

  const durableScore = Math.round(
    input.residueScore * 0.4 +
      input.revisits * 10 +
      input.copies * 12 +
      input.reflections * 18 +
      (survivesNovelty ? 15 : 0) -
      (noveltyOnly ? 25 : 0),
  );

  return {
    id: input.id,
    text: input.text,
    durableScore: Math.max(0, Math.min(100, durableScore)),
    revisits: input.revisits,
    copies: input.copies,
    delayedReflections: input.reflections,
    survivesNovelty,
    noveltyOnly,
  };
}

/** Detect emotionally durable callbacks vs novelty-only flashes. */
export function buildDurableCallbacksReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): DurableCallbacksReport {
  const loopReport = buildLoopOptimizationReport(entries);
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const loopMetrics = collectLoopMetrics(loopReport);

  const rows: DurableCallbackRow[] = [];

  for (const metric of loopMetrics) {
    rows.push(
      rowFromMetrics({
        id: metric.noteId,
        text: metric.noteText,
        revisits: metric.revisits,
        copies: metric.copies,
        reflections: metric.reflections,
        residueScore: metric.residueScore,
        pauseScore: metric.dwellMs >= 6000 ? 60 : 40,
        dead: metric.dead,
        halfLifeScore: metric.halfLifeScore,
      }),
    );
  }

  for (const item of callbackReport.items) {
    if (rows.some((r) => r.id === item.id)) continue;
    rows.push(
      rowFromMetrics({
        id: item.id,
        text: item.text,
        revisits: item.survival.oldEntryRevisitCount,
        copies: item.survival.copiedMemoryMomentCount,
        reflections: item.survival.followUpCompleteCount,
        residueScore: item.emotionalResidueScore,
        pauseScore: item.pause.pauseScore,
        dead: item.cutCandidate,
      }),
    );
  }

  const sorted = [...rows].sort((a, b) => b.durableScore - a.durableScore);

  return {
    generatedAt: new Date().toISOString(),
    hasData: sorted.length > 0,
    leaders: sorted.filter((r) => r.survivesNovelty && !r.noveltyOnly).slice(0, 12),
    fadedAfterNovelty: sorted
      .filter((r) => r.noveltyOnly || (r.durableScore < 35 && r.revisits === 0))
      .slice(0, 12),
    noveltyOnly: sorted.filter((r) => r.noveltyOnly).slice(0, 12),
  };
}

export function isDurableCallback(callbackId: string, entries?: JournalEntry[]): boolean {
  const report = buildDurableCallbacksReport(entries);
  return report.leaders.some((row) => row.id === callbackId);
}

export function boostDurableCallbackScore(baseScore: number, callbackId: string, entries?: JournalEntry[]): number {
  if (!isDurableCallback(callbackId, entries)) return baseScore;
  return Math.min(100, baseScore + 8);
}
