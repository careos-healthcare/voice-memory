import {
  aggregateLineMetrics,
  countRoundupEvent,
  lineContinuationScore,
  lineIgnoreRatio,
  ROUNDUP_CONTINUE_CLICKED,
  ROUNDUP_FOLLOWUP_RECORDED,
  ROUNDUP_INSTANT_ABANDON,
  ROUNDUP_LINE_PAUSED,
  ROUNDUP_OPENED,
  ROUNDUP_RETURN_AFTER,
} from "@/lib/roundups/roundup-observation";
import type {
  RoundupLineMetricRow,
  RoundupObservationReport,
  RoundupPauseNoActionRow,
} from "@/types/roundup-observation";
import { readLocalEvents } from "@/lib/local-analytics";

function toMetricRow(
  row: ReturnType<typeof aggregateLineMetrics> extends Map<string, infer V> ? V : never,
): RoundupLineMetricRow {
  const ignoreRatio = lineIgnoreRatio(row);
  const continuationScore = lineContinuationScore(row);
  const exposures = row.pauses + row.relatedEntryOpens;
  const actions =
    row.continues +
    row.followupsRecorded +
    row.bookmarks +
    row.copies +
    row.intentionsSaved;

  return {
    lineKey: row.lineKey,
    text: row.text,
    signal: row.signal,
    pauses: row.pauses,
    copies: row.copies,
    bookmarks: row.bookmarks,
    continues: row.continues,
    intentionsSaved: row.intentionsSaved,
    relatedEntryOpens: row.relatedEntryOpens,
    followupsRecorded: row.followupsRecorded,
    continuationScore,
    ignoreRatio,
    dead: exposures >= 3 && actions === 0 && ignoreRatio >= 0.85,
  };
}

export function buildRoundupObservationReport(): RoundupObservationReport {
  const metrics = [...aggregateLineMetrics().values()].map(toMetricRow);

  const pauses = countRoundupEvent(ROUNDUP_LINE_PAUSED);
  const continues = countRoundupEvent(ROUNDUP_CONTINUE_CLICKED);
  const followups = countRoundupEvent(ROUNDUP_FOLLOWUP_RECORDED);
  const conversionDenom = pauses + countRoundupEvent(ROUNDUP_OPENED);
  const conversionNum = continues + followups;
  const continuationConversion =
    conversionDenom > 0
      ? `${Math.round((conversionNum / conversionDenom) * 100)}%`
      : "—";

  const pauseWithNoAction: RoundupPauseNoActionRow[] = [...aggregateLineMetrics().values()]
    .filter((row) => {
      const actions =
        row.continues +
        row.followupsRecorded +
        row.bookmarks +
        row.copies +
        row.intentionsSaved +
        row.relatedEntryOpens;
      return row.pauses > 0 && actions === 0;
    })
    .map((row) => ({
      lineKey: row.lineKey,
      text: row.text,
      signal: row.signal,
      pauseCount: row.pauses,
      dwellMs: row.pauseDwellMs,
    }))
    .sort((a, b) => b.pauseCount - a.pauseCount)
    .slice(0, 12);

  const returns24h = readLocalEvents().filter(
    (event) => event.name === ROUNDUP_RETURN_AFTER && event.meta?.window === "24h",
  ).length;
  const returns7d = readLocalEvents().filter(
    (event) => event.name === ROUNDUP_RETURN_AFTER && event.meta?.window === "7d",
  ).length;

  return {
    generatedAt: new Date().toISOString(),
    hasData: metrics.length > 0 || countRoundupEvent(ROUNDUP_OPENED) > 0,
    roundupOpens: countRoundupEvent(ROUNDUP_OPENED),
    instantAbandons: countRoundupEvent(ROUNDUP_INSTANT_ABANDON),
    returns24h,
    returns7d,
    continuationConversion,
    topContinuationLines: [...metrics]
      .sort((a, b) => b.continuationScore - a.continuationScore)
      .slice(0, 10),
    deadRoundupLines: metrics.filter((row) => row.dead).slice(0, 10),
    revisitDrivingLines: [...metrics]
      .sort((a, b) => b.relatedEntryOpens - a.relatedEntryOpens)
      .filter((row) => row.relatedEntryOpens > 0)
      .slice(0, 10),
    copiedLines: [...metrics]
      .filter((row) => row.copies > 0)
      .sort((a, b) => b.copies - a.copies)
      .slice(0, 10),
    bookmarkDrivingLines: [...metrics]
      .filter((row) => row.bookmarks > 0)
      .sort((a, b) => b.bookmarks - a.bookmarks)
      .slice(0, 10),
    pauseWithNoAction,
  };
}
