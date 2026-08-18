import { getRoundupReviewLabels } from "@/lib/debug/roundup-review-labels";
import { evaluateRoundupCandidates } from "@/lib/roundups/roundup-quality";
import {
  buildLastMonthPeriod,
  buildLastNDaysPeriod,
  buildMonthlyPeriod,
  buildWeeklyPeriod,
  collectRoundupLineCandidates,
} from "@/lib/roundups/reflective-roundups";
import { addDaysToKey, startOfWeekKey, todayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  RoundupQualityReason,
  RoundupQualityReviewItem,
  RoundupQualityReviewPeriod,
  RoundupQualityReviewReport,
} from "@/types/roundup-quality-review";
import type { RoundupPeriod } from "@/types/reflective-roundup";

function reviewPeriod(
  period: RoundupPeriod,
  entries: JournalEntry[],
): RoundupQualityReviewPeriod {
  const candidates = collectRoundupLineCandidates(period, entries);
  const evaluated = evaluateRoundupCandidates(candidates);

  const items: RoundupQualityReviewItem[] = evaluated.map((row, index) => {
    const id = `${period.slug}-${row.candidate.signal}-${index}`;
    return {
      id,
      periodSlug: period.slug,
      periodLabel: period.label,
      text: row.candidate.text,
      signal: row.candidate.signal,
      score: row.candidate.score,
      entryIds: row.candidate.entryIds,
      qualitySuppressed: row.qualitySuppressed,
      qualityReasons: row.qualityReasons,
      selected: row.selected,
      manualLabels: getRoundupReviewLabels(id),
    };
  });

  return {
    periodSlug: period.slug,
    periodLabel: period.label,
    startDayKey: period.startDayKey,
    endDayKey: period.endDayKey,
    items,
    selectedCount: items.filter((item) => item.selected).length,
    suppressedCount: items.filter((item) => item.qualitySuppressed).length,
  };
}

function defaultReviewPeriods(): RoundupPeriod[] {
  const end = todayKey();
  const lastWeekEnd = addDaysToKey(startOfWeekKey(end), -1);
  return [
    buildWeeklyPeriod(end),
    buildWeeklyPeriod(lastWeekEnd),
    buildMonthlyPeriod(),
    buildLastMonthPeriod(),
    buildLastNDaysPeriod(7),
    buildLastNDaysPeriod(30),
  ];
}

export function buildRoundupQualityReviewReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
  periods: RoundupPeriod[] = defaultReviewPeriods(),
): RoundupQualityReviewReport {
  const reviewed = periods.map((period) => reviewPeriod(period, entries));
  const allItems = reviewed.flatMap((period) => period.items);

  const byReason: Partial<Record<RoundupQualityReason, number>> = {};
  for (const item of allItems) {
    for (const reason of item.qualityReasons) {
      byReason[reason] = (byReason[reason] ?? 0) + 1;
    }
  }

  return {
    generatedAt: new Date().toISOString(),
    periods: reviewed,
    totalCandidates: allItems.length,
    totalSuppressed: allItems.filter((item) => item.qualitySuppressed).length,
    totalSelected: allItems.filter((item) => item.selected).length,
    byReason,
    hasData: allItems.length > 0,
  };
}
