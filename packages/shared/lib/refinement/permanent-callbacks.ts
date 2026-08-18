import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import { buildDurableCallbacksReport, isDurableCallback } from "@/lib/refinement/durable-callbacks";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { PermanentCallbackRow, PermanentCallbacksReport } from "@/types/archive-permanence-layer";

const PERMANENT_MIN_MONTHS = 3;
const PERMANENT_MIN_REVISITS = 2;
const NOVELTY_SPIKE_THRESHOLD = 65;
const TEMPORARY_SPIKE_RESIDUE = 55;

function collectLoopMetrics(report: ReturnType<typeof buildLoopOptimizationReport>) {
  const merged = [
    ...report.topPerforming,
    ...report.causingRevisits,
    ...report.causingReflections,
    ...report.causingBookmarks,
    ...report.topCopied,
  ];
  const seen = new Set<string>();
  return merged.filter((row) => {
    if (seen.has(row.noteId)) return false;
    seen.add(row.noteId);
    return true;
  });
}

function monthsSpanForCallback(callbackId: string, entries: JournalEntry[]): number {
  const related = entries.filter((entry) => {
    const pattern = entry.reflection.exactLanguagePattern?.trim();
    const observation = entry.reflection.concreteObservation?.trim();
    return entry.id === callbackId || pattern?.includes(callbackId) || observation?.includes(callbackId);
  });

  if (related.length < 2) {
    const entry = entries.find((e) => e.id === callbackId);
    if (!entry) return 0;
    const oldest = entries[0]?.createdAt;
    const newest = entries[entries.length - 1]?.createdAt;
    if (!oldest || !newest) return 0;
    const days = daysBetweenKeys(toDayKey(oldest), toDayKey(newest));
    return Math.floor(days / 30);
  }

  const sorted = [...related].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const days = daysBetweenKeys(toDayKey(sorted[0].createdAt), toDayKey(sorted[sorted.length - 1].createdAt));
  return Math.floor(days / 30);
}

function rowFromSignals(input: {
  id: string;
  text: string;
  revisits: number;
  copies: number;
  reflections: number;
  monthsSpan: number;
  residueScore: number;
  pauseScore: number;
  archiveIdentity: boolean;
}): PermanentCallbackRow {
  const permanentScore = Math.round(
    input.residueScore * 0.35 +
      input.revisits * 12 +
      input.copies * 14 +
      input.reflections * 20 +
      input.monthsSpan * 8 +
      (input.archiveIdentity ? 18 : 0),
  );

  return {
    id: input.id,
    text: input.text,
    permanentScore: Math.max(0, Math.min(100, permanentScore)),
    revisits: input.revisits,
    copies: input.copies,
    delayedReflections: input.reflections,
    monthsSpan: input.monthsSpan,
    archiveIdentity: input.archiveIdentity,
  };
}

function isNoveltyOnly(row: PermanentCallbackRow, pauseScore: number): boolean {
  return (
    pauseScore >= NOVELTY_SPIKE_THRESHOLD &&
    row.revisits === 0 &&
    row.copies === 0 &&
    row.delayedReflections === 0 &&
    row.monthsSpan < 2
  );
}

function isTemporarySpike(row: PermanentCallbackRow, residueScore: number): boolean {
  return (
    residueScore >= TEMPORARY_SPIKE_RESIDUE &&
    row.revisits <= 1 &&
    row.monthsSpan < PERMANENT_MIN_MONTHS &&
    !row.archiveIdentity
  );
}

/** Detect emotionally permanent callbacks that survive months and revisits. */
export function buildPermanentCallbacksReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): PermanentCallbacksReport {
  const loopReport = buildLoopOptimizationReport(entries);
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const loopMetrics = collectLoopMetrics(loopReport);
  const durable = buildDurableCallbacksReport(entries);

  const rows: PermanentCallbackRow[] = [];

  for (const metric of loopMetrics) {
    const monthsSpan = monthsSpanForCallback(metric.noteId, entries);
    const archiveIdentity =
      isDurableCallback(metric.noteId, entries) &&
      metric.revisits >= PERMANENT_MIN_REVISITS &&
      monthsSpan >= PERMANENT_MIN_MONTHS;

    rows.push(
      rowFromSignals({
        id: metric.noteId,
        text: metric.noteText,
        revisits: metric.revisits,
        copies: metric.copies,
        reflections: metric.reflections,
        monthsSpan,
        residueScore: metric.residueScore,
        pauseScore: metric.dwellMs >= 6000 ? 60 : 35,
        archiveIdentity,
      }),
    );
  }

  for (const item of callbackReport.items) {
    if (rows.some((r) => r.id === item.id)) continue;
    const monthsSpan = monthsSpanForCallback(item.id, entries);
    rows.push(
      rowFromSignals({
        id: item.id,
        text: item.text,
        revisits: item.survival.oldEntryRevisitCount,
        copies: item.survival.copiedMemoryMomentCount,
        reflections: item.survival.followUpCompleteCount,
        monthsSpan,
        residueScore: item.emotionalResidueScore,
        pauseScore: item.pause.pauseScore,
        archiveIdentity:
          durable.leaders.some((l) => l.id === item.id) && monthsSpan >= PERMANENT_MIN_MONTHS,
      }),
    );
  }

  const sorted = [...rows].sort((a, b) => b.permanentScore - a.permanentScore);

  const permanent = sorted.filter(
    (row) =>
      row.permanentScore >= 55 &&
      (row.monthsSpan >= PERMANENT_MIN_MONTHS || row.revisits >= PERMANENT_MIN_REVISITS + 1) &&
      (row.revisits >= PERMANENT_MIN_REVISITS ||
        row.copies >= 1 ||
        row.delayedReflections >= 1),
  );

  const suppressedNovelty = sorted.filter((row) => {
    const metric = loopMetrics.find((m) => m.noteId === row.id);
    const pauseScore = metric ? (metric.dwellMs >= 6000 ? 60 : 35) : 40;
    return isNoveltyOnly(row, pauseScore);
  });

  const temporarySpikes = sorted.filter((row) => {
    const item = callbackReport.items.find((i) => i.id === row.id);
    return isTemporarySpike(row, item?.emotionalResidueScore ?? 0);
  });

  return {
    generatedAt: new Date().toISOString(),
    hasData: sorted.length > 0,
    permanent: permanent.slice(0, 12),
    suppressedNovelty: suppressedNovelty.slice(0, 10),
    temporarySpikes: temporarySpikes.slice(0, 10),
  };
}

export function isPermanentCallback(callbackId: string, entries?: JournalEntry[]): boolean {
  const report = buildPermanentCallbacksReport(entries);
  return report.permanent.some((row) => row.id === callbackId);
}

export function boostPermanentCallbackScore(
  baseScore: number,
  callbackId: string,
  entries?: JournalEntry[],
): number {
  if (!isPermanentCallback(callbackId, entries)) return baseScore;
  return Math.min(100, baseScore + 10);
}
