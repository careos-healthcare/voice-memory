import {
  analyzeRecurrenceDensitySignals,
  computeRecurrenceDensityMetrics,
  listRecurrenceDensityEvents,
  previewRecurrenceDensityPrompt,
  readRecurrenceDensityState,
} from "@/lib/retention/recurrence-density";
import { firstWeekDayIndex, isWithinFirstWeek } from "@/lib/retention/first-week";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { RecurrenceDensityDebugReport } from "@/types/recurrence-density";

/** Internal review — week-one recurrence signals and prompt gating. */
export function buildRecurrenceDensityDebugReport(): RecurrenceDensityDebugReport {
  const entries = getMemoryEligibleEntries();
  const withinFirstWeek = isWithinFirstWeek(entries);

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length > 0,
    withinFirstWeek,
    dayIndex: firstWeekDayIndex(entries),
    state: readRecurrenceDensityState(),
    metrics: computeRecurrenceDensityMetrics(entries),
    signals: analyzeRecurrenceDensitySignals(entries),
    previewOffer: previewRecurrenceDensityPrompt(entries),
    recentEvents: listRecurrenceDensityEvents(32),
  };
}
