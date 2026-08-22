import "server-only";

import type { CuriosityJournalEntryTiming } from "./types";

const FALLBACK_DELAY_MS = 24 * 60 * 60 * 1000;
const MIN_HISTORY_ENTRIES = 3;
const MAX_SAMPLE_SIZE = 5;

/**
 * Computes when to fire the next curiosity notification from journal rhythm.
 */
export class CuriosityAdaptiveTimingEngine {
  calculateOptimalDelayMs(input: {
    history: readonly CuriosityJournalEntryTiming[];
    currentEntryTime: Date;
  }): number {
    if (input.history.length < MIN_HISTORY_ENTRIES) {
      return FALLBACK_DELAY_MS;
    }

    const recent = recentEntries(input.history, MAX_SAMPLE_SIZE);
    const averageHour =
      recent.map(hourOfDay).reduce((sum, hour) => sum + hour, 0) / recent.length;

    const currentLocal = input.currentEntryTime;
    const nextDay = new Date(
      currentLocal.getFullYear(),
      currentLocal.getMonth(),
      currentLocal.getDate() + 1,
    );

    const targetHour = Math.min(23, Math.max(0, Math.floor(averageHour)));
    const targetMinute = Math.min(
      59,
      Math.max(0, Math.round((averageHour - targetHour) * 60)),
    );

    const target = new Date(
      nextDay.getFullYear(),
      nextDay.getMonth(),
      nextDay.getDate(),
      targetHour,
      targetMinute,
    );

    const delay = target.getTime() - currentLocal.getTime();
    return delay > 0 ? delay : FALLBACK_DELAY_MS;
  }
}

function recentEntries(
  history: readonly CuriosityJournalEntryTiming[],
  limit: number,
): CuriosityJournalEntryTiming[] {
  const sorted = [...history].sort(
    (left, right) => Date.parse(left.createdAt) - Date.parse(right.createdAt),
  );
  if (sorted.length <= limit) return sorted;
  return sorted.slice(sorted.length - limit);
}

function hourOfDay(entry: CuriosityJournalEntryTiming): number {
  const local = new Date(entry.createdAt);
  return local.getHours() + local.getMinutes() / 60;
}

export const curiosityAdaptiveTimingEngine = new CuriosityAdaptiveTimingEngine();
