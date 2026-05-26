import {
  assessResurfacingTiming,
  collectResurfacingTimingCandidates,
} from "@/lib/revisit/resurfacing-timing";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ResurfacingTimingClass,
  ResurfacingTimingDebugReport,
  ResurfacingTimingReviewRow,
  ResurfacingTimingVerdict,
} from "@/types/resurfacing-timing";

function toReviewRow(verdict: ResurfacingTimingVerdict): ResurfacingTimingReviewRow {
  return {
    noteId: verdict.noteId,
    entryId: verdict.entryId ?? "",
    text: verdict.text,
    timingEligible: verdict.timingEligible,
    timingScore: verdict.timingScore,
    timingClass: verdict.timingClass,
    reasons: verdict.reasons,
    suppressReasons: verdict.suppressReasons,
    nextEligibleAt: verdict.nextEligibleAt,
  };
}

function countSuppressReasons(
  rows: ResurfacingTimingReviewRow[],
): Array<{ reason: string; count: number }> {
  const counts = new Map<string, number>();
  for (const row of rows) {
    for (const reason of row.suppressReasons) {
      counts.set(reason, (counts.get(reason) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .map(([reason, count]) => ({ reason, count }))
    .sort((a, b) => b.count - a.count);
}

export function buildResurfacingTimingDebugReport(): ResurfacingTimingDebugReport {
  const entries = getMemoryEligibleEntries();
  const candidates = collectResurfacingTimingCandidates(entries);
  const verdicts = candidates.map((note) => assessResurfacingTiming(note, entries));
  const rows = verdicts.map(toReviewRow);

  const byClass = verdicts.reduce(
    (acc, verdict) => {
      acc[verdict.timingClass] += 1;
      return acc;
    },
    {
      too_early: 0,
      cooling_down: 0,
      eligible: 0,
      strong_timing: 0,
    } satisfies Record<ResurfacingTimingClass, number>,
  );

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0,
    totalCandidates: rows.length,
    tooEarly: rows.filter((row) => row.timingClass === "too_early"),
    coolingDown: rows.filter((row) => row.timingClass === "cooling_down"),
    eligible: rows.filter((row) => row.timingClass === "eligible"),
    strongTiming: rows.filter((row) => row.timingClass === "strong_timing"),
    topSuppressReasons: countSuppressReasons(rows).slice(0, 10),
    byClass,
  };
}
