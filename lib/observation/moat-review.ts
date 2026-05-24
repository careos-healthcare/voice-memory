import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import {
  buildMoatMetricsReport,
  MOAT_TARGET_MEMORY_LINE_OPEN_RATE,
  MOAT_TARGET_OLD_ENTRY_REVISIT_RATE,
} from "@/lib/retention/moat-metrics";
import { getAllEntries } from "@/lib/storage";
import type { MoatReviewMetric, MoatReviewReport } from "@/types/observation-workflow";

export const MOAT_REVIEW_TARGET_REVISIT_TO_REFLECTION = 15;
export const MOAT_REVIEW_TARGET_FOLLOWUP = 15;
export const MOAT_REVIEW_TARGET_BOOKMARK = 10;

function parsePct(value: string): number {
  const n = Number.parseInt(value.replace("%", ""), 10);
  return Number.isFinite(n) ? n : 0;
}

function pct(count: number, total: number): string {
  if (total <= 0) return "—";
  return `${Math.round((count / total) * 100)}%`;
}

/** Single moat scoreboard — exact behavior vs targets. Debug only. */
export function buildMoatReviewReport(): MoatReviewReport {
  const moat = buildMoatMetricsReport();
  const loops = buildRetentionLoopReport();
  const entries = getAllEntries();

  const oldEntryRevisitRate = parsePct(moat.oldEntryRevisitRate);
  const revisitToReflection = parsePct(moat.revisitToReflection7d);
  const memoryLineOpen = parsePct(moat.memoryLineToOldEntryOpenRate);

  const followupStarted = loops.events.filter((row) => row.kind === "followup_recording_started").length;
  const followupCompleted = loops.events.filter(
    (row) => row.kind === "followup_recording_completed",
  ).length;
  const revisits = moat.oldEntryRevisitCount;
  const followupRate =
    followupStarted > 0
      ? Math.round((followupCompleted / followupStarted) * 100)
      : revisits > 0
        ? Math.round((followupCompleted / revisits) * 100)
        : 0;

  const bookmarks = loops.events.filter((row) => row.kind === "bookmark_created").length;
  const bookmarkRate =
    entries.length > 0 ? Math.round((bookmarks / entries.length) * 100) : 0;

  const copied = loops.events.filter((row) => row.kind === "copied_memory_moment").length;
  const d7 = loops.returnIndicators.day7Count;
  const d1 = loops.returnIndicators.day1Count;
  const d30Proxy = loops.events.filter((row) => row.kind === "returned_within_7_days").length;

  const metrics: MoatReviewMetric[] = [
    {
      id: "old_entry_revisit",
      label: "Old-entry revisit rate",
      current: moat.oldEntryRevisitRate,
      currentValue: oldEntryRevisitRate,
      target: `${MOAT_TARGET_OLD_ENTRY_REVISIT_RATE}%`,
      targetValue: MOAT_TARGET_OLD_ENTRY_REVISIT_RATE,
      met: oldEntryRevisitRate >= MOAT_TARGET_OLD_ENTRY_REVISIT_RATE,
      countHint: `${moat.oldEntryRevisitCount} revisits / ${moat.oldEntriesInArchive} old entries`,
    },
    {
      id: "revisit_to_reflection",
      label: "Revisit → new reflection",
      current: moat.revisitToReflection7d,
      currentValue: revisitToReflection,
      target: `${MOAT_REVIEW_TARGET_REVISIT_TO_REFLECTION}%`,
      targetValue: MOAT_REVIEW_TARGET_REVISIT_TO_REFLECTION,
      met: revisitToReflection >= MOAT_REVIEW_TARGET_REVISIT_TO_REFLECTION,
      countHint: `${moat.revisitToReflection7dCount} / ${moat.oldEntryRevisitCount} revisits (7d)`,
    },
    {
      id: "memory_note_to_entry",
      label: "Memory note → old entry open",
      current: moat.memoryLineToOldEntryOpenRate,
      currentValue: memoryLineOpen,
      target: `${MOAT_TARGET_MEMORY_LINE_OPEN_RATE}%`,
      targetValue: MOAT_TARGET_MEMORY_LINE_OPEN_RATE,
      met: memoryLineOpen >= MOAT_TARGET_MEMORY_LINE_OPEN_RATE,
      countHint: `${moat.memoryLineToOldEntryOpenCount} opens / ${moat.memoryLineClickCount} clicks`,
    },
    {
      id: "followup_continuation",
      label: "Follow-up continuation",
      current: pct(followupCompleted, Math.max(1, followupStarted)),
      currentValue: followupRate,
      target: `${MOAT_REVIEW_TARGET_FOLLOWUP}%`,
      targetValue: MOAT_REVIEW_TARGET_FOLLOWUP,
      met: followupRate >= MOAT_REVIEW_TARGET_FOLLOWUP,
      countHint: `${followupCompleted} completed / ${followupStarted} started`,
    },
    {
      id: "bookmark_rate",
      label: "Bookmark rate",
      current: pct(bookmarks, Math.max(1, entries.length)),
      currentValue: bookmarkRate,
      target: `${MOAT_REVIEW_TARGET_BOOKMARK}%`,
      targetValue: MOAT_REVIEW_TARGET_BOOKMARK,
      met: bookmarkRate >= MOAT_REVIEW_TARGET_BOOKMARK,
      countHint: `${bookmarks} bookmarks / ${entries.length} reflections`,
    },
    {
      id: "copied_moments",
      label: "Copied moments",
      current: String(copied),
      currentValue: copied,
      target: "—",
      targetValue: 0,
      met: copied > 0,
      countHint: "Count only — no target",
    },
    {
      id: "d7_return",
      label: "D7 return",
      current: String(d7),
      currentValue: d7,
      target: "—",
      targetValue: 0,
      met: d7 > 0,
      countHint: `${d1} day-1 returns also recorded`,
    },
    {
      id: "d30_return",
      label: "D30 return (proxy)",
      current: String(d30Proxy),
      currentValue: d30Proxy,
      target: "—",
      targetValue: 0,
      met: d30Proxy > 0,
      countHint: "Uses 7-day return events as local proxy",
    },
  ];

  const withTargets = metrics.filter((row) => row.targetValue > 0);
  const metCount = withTargets.filter((row) => row.met).length;

  return {
    generatedAt: new Date().toISOString(),
    metrics,
    metCount,
    totalCount: withTargets.length,
    hasData: moat.hasData || entries.length > 0,
  };
}
