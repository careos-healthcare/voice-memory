import { startOfWeekKey, toDayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { SoftEmotionalTimelineReport, SoftTimelineSegment } from "@/types/personalization";

function feelingLine(avg: number, count: number): string {
  if (count <= 1) return "A single note from this stretch.";
  if (avg >= 7) return "This stretch carried more weight.";
  if (avg <= 4) return "Things felt quieter here.";
  if (avg >= 5.5) return "A steadier, fuller stretch.";
  return "Mixed days — neither loud nor empty.";
}

function intensityBand(avg: number): SoftTimelineSegment["intensityBand"] {
  if (avg >= 7) return "heavy";
  if (avg <= 4) return "quiet";
  if (avg >= 5.8) return "steady";
  return "mixed";
}

function periodLabel(weekKey: string): string {
  const [year, month, day] = weekKey.split("-").map(Number);
  const date = new Date(year, month - 1, day);
  return new Intl.DateTimeFormat("en-US", { month: "long", day: "numeric" }).format(date);
}

/** Gentle movement over time — no charts, scores, or clinical labels. */
export function buildSoftEmotionalTimelineReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): SoftEmotionalTimelineReport {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );

  const buckets = new Map<string, JournalEntry[]>();
  for (const entry of sorted) {
    const week = startOfWeekKey(toDayKey(entry.createdAt));
    const list = buckets.get(week) ?? [];
    list.push(entry);
    buckets.set(week, list);
  }

  const segments: SoftTimelineSegment[] = [...buckets.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-12)
    .map(([week, weekEntries]) => {
      const avg =
        weekEntries.reduce((sum, e) => sum + e.reflection.emotionalIntensity, 0) /
        weekEntries.length;
      return {
        id: `week-${week}`,
        periodLabel: periodLabel(week),
        feelingLine: feelingLine(avg, weekEntries.length),
        intensityBand: intensityBand(avg),
      };
    });

  return {
    generatedAt: new Date().toISOString(),
    hasData: segments.length > 0,
    segments,
  };
}
