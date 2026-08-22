import {
  assessResurfacingWhyNow,
  collectResurfacingWhyNowCandidates,
} from "@/lib/revisit/resurfacing-why-now";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ResurfacingWhyNowDebugReport,
  ResurfacingWhyNowKind,
  ResurfacingWhyNowReviewRow,
  ResurfacingWhyNowVerdict,
} from "@/types/resurfacing-why-now";

function toReviewRow(verdict: ResurfacingWhyNowVerdict): ResurfacingWhyNowReviewRow {
  return {
    noteId: verdict.noteId,
    entryId: verdict.entryId ?? "",
    text: verdict.text,
    explanation: verdict.explanation,
    primaryKind: verdict.primaryKind,
    signalCount: verdict.signals.length,
    signals: verdict.signals,
    evidenceBacked: verdict.evidenceBacked,
    blockedReason: verdict.blockedReason,
  };
}

function countByExplanation(
  rows: ResurfacingWhyNowReviewRow[],
): Array<{ explanation: string; count: number }> {
  const counts = new Map<string, number>();
  for (const row of rows) {
    if (!row.explanation) continue;
    counts.set(row.explanation, (counts.get(row.explanation) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([explanation, count]) => ({ explanation, count }))
    .sort((a, b) => b.count - a.count);
}

export function buildResurfacingWhyNowDebugReport(): ResurfacingWhyNowDebugReport {
  const entries = getMemoryEligibleEntries();
  const candidates = collectResurfacingWhyNowCandidates(entries);
  const verdicts = candidates.map((note) => assessResurfacingWhyNow(note, entries));
  const rows = verdicts.map(toReviewRow);

  const byKind = verdicts.reduce(
    (acc, verdict) => {
      if (verdict.primaryKind) acc[verdict.primaryKind] += 1;
      return acc;
    },
    {
      repeated_phrase_after_gap: 0,
      repeated_concern_after_gap: 0,
      named_person_topic_return: 0,
      same_time_of_day: 0,
      same_weekday: 0,
      same_emotional_state: 0,
      mood_shift_same_topic: 0,
      quiet_gap_return: 0,
      repeated_avoidance_language: 0,
      repeated_future_language: 0,
    } satisfies Record<ResurfacingWhyNowKind, number>,
  );

  const withExplanation = rows.filter((row) => row.explanation);
  const withoutExplanation = rows.filter((row) => !row.explanation);
  const blockedSamples = rows.filter((row) => row.blockedReason).slice(0, 8);

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0,
    totalCandidates: rows.length,
    withExplanation,
    withoutExplanation,
    byKind,
    topExplanations: countByExplanation(withExplanation).slice(0, 10),
    blockedSamples,
  };
}
