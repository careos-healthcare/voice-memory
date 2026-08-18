import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { LAUNCH_EVENTS, readLocalEvents } from "@/lib/local-analytics";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { SESSION_RETENTION_EVENTS } from "@/lib/retention/session-retention";
import {
  hoursBetween,
  medianHours,
  qualifyInterpretation,
  sampleConfidence,
} from "@/lib/behavior/helpers";
import type {
  ReturnTimingMetric,
  UserReturnSegment,
  UserReturnSegmentRow,
} from "@/types/behavior-truth";
import type { LocalAnalyticsEvent } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

function reflectionGapsHours(entries: JournalEntry[]): number[] {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const gaps: number[] = [];
  for (let i = 1; i < sorted.length; i += 1) {
    gaps.push(hoursBetween(sorted[i - 1].createdAt, sorted[i].createdAt));
  }
  return gaps;
}

function gapsAfterEvent(
  entries: JournalEntry[],
  anchorAt: string,
): number[] {
  const anchorMs = new Date(anchorAt).getTime();
  const after = entries
    .filter((entry) => new Date(entry.createdAt).getTime() > anchorMs)
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
  if (after.length === 0) return [];
  const first = after[0];
  return [hoursBetween(anchorAt, first.createdAt)];
}

export function computeReturnTiming(
  events: LocalAnalyticsEvent[],
  entries: JournalEntry[],
): ReturnTimingMetric[] {
  const gaps = reflectionGapsHours(entries);
  const medianSecond = gaps.length > 0 ? medianHours(gaps) : null;

  const callbackReflectionGaps: number[] = [];
  for (const event of events) {
    if (event.name !== CALLBACK_LEARNING_EVENTS.reflectionAfter) continue;
    const gapList = gapsAfterEvent(entries, event.at);
    callbackReflectionGaps.push(...gapList);
  }
  const medianAfterCallback = medianHours(callbackReflectionGaps);

  const day2At = events.find((e) => e.name === SESSION_RETENTION_EVENTS.day2Return)?.at;
  const firstAt =
    events.find((e) => e.name === LAUNCH_EVENTS.firstReflectionCreated)?.at ??
    entries[0]?.createdAt;
  let day2Hours: number | null = null;
  if (day2At && firstAt) {
    day2Hours = Math.round(hoursBetween(firstAt, day2At));
  }

  const lastEntry = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  )[0];
  const silenceDays =
    lastEntry && entries.length >= 1
      ? daysBetweenKeys(toDayKey(lastEntry.createdAt), toDayKey(new Date().toISOString()))
      : null;

  const confSecond = sampleConfidence(gaps.length);
  const confCallback = sampleConfidence(callbackReflectionGaps.length);

  return [
    {
      label: "Hours to second reflection (median)",
      medianHours: medianSecond,
      sampleCount: gaps.length,
      plain: medianSecond
        ? qualifyInterpretation(
            `About ${medianSecond} hours between reflections on this device.`,
            confSecond,
          )
        : "Not enough reflections yet to estimate return spacing.",
    },
    {
      label: "Hours after callback → next reflection (median)",
      medianHours: medianAfterCallback,
      sampleCount: callbackReflectionGaps.length,
      plain: medianAfterCallback
        ? qualifyInterpretation(
            `After opening a callback, the next reflection often arrives within ~${medianAfterCallback} hours.`,
            confCallback,
          )
        : "No callback-tied reflections logged yet.",
    },
    {
      label: "Day-2 return timing",
      medianHours: day2Hours,
      sampleCount: day2At ? 1 : 0,
      plain: day2Hours
        ? `Day-2 return logged about ${day2Hours} hours after the first reflection anchor.`
        : "Day-2 return not logged on this device yet.",
    },
    {
      label: "Silence before last reflection",
      medianHours: silenceDays !== null ? silenceDays * 24 : null,
      sampleCount: entries.length,
      plain:
        silenceDays === null
          ? "No reflections yet."
          : silenceDays >= 7
            ? `Last reflection was ${silenceDays} days ago — quiet spell before any new return.`
            : `Last reflection was ${silenceDays} day(s) ago — still within an active week.`,
    },
  ];
}

export function computeUserReturnSegments(
  events: LocalAnalyticsEvent[],
  entries: JournalEntry[],
): UserReturnSegmentRow[] {
  const reflectionCount = entries.length;
  const gaps = reflectionGapsHours(entries);
  const medianGap = medianHours(gaps);
  const openLoops = events.filter((e) => e.name === "open_loop_created").length;
  const callbackOpens = events.filter((e) => e.name === CALLBACK_LEARNING_EVENTS.opened).length;
  const day2 = events.some((e) => e.name === SESSION_RETENTION_EVENTS.day2Return);

  const segments: UserReturnSegment[] = [];

  if (reflectionCount < 2) {
    segments.push("insufficient_data");
  } else if (reflectionCount >= 4 && (medianGap ?? 999) < 72) {
    segments.push("emotionally_active");
  } else if (reflectionCount >= 2 && (medianGap ?? 0) > 168 && !day2) {
    segments.push("one_and_done");
  } else if (day2 || (medianGap !== null && medianGap >= 24 && medianGap <= 168)) {
    segments.push("quiet_returner");
  } else {
    segments.push("insufficient_data");
  }

  const labels: Record<UserReturnSegment, { label: string; plain: string }> = {
    emotionally_active: {
      label: "Emotionally active",
      plain: "Multiple reflections with relatively short gaps — this device shows active emotional use.",
    },
    one_and_done: {
      label: "One-and-done risk",
      plain: "A second reflection exists but gaps are long and day-2 return is missing — habit may not have formed.",
    },
    quiet_returner: {
      label: "Quiet returner",
      plain: "Returns happen with breathing room — not daily use, but not abandoned either.",
    },
    insufficient_data: {
      label: "Not enough signal",
      plain: "Too few reflections on this device to classify return style reliably.",
    },
  };

  return segments.map((segment) => ({
    segment,
    label: labels[segment].label,
    plain: labels[segment].plain,
    signals: [
      `reflections=${reflectionCount}`,
      medianGap !== null ? `median_gap_hours=${medianGap}` : "median_gap_hours=—",
      `open_loops=${openLoops}`,
      `callback_opens=${callbackOpens}`,
      day2 ? "day_2_return=yes" : "day_2_return=no",
    ],
  }));
}

export function buildReturnAnalysis(): {
  timing: ReturnTimingMetric[];
  segments: UserReturnSegmentRow[];
} {
  if (typeof window === "undefined") {
    return { timing: [], segments: [] };
  }
  const entries = getMemoryEligibleEntries();
  const events = readLocalEvents();
  return {
    timing: computeReturnTiming(events, entries),
    segments: computeUserReturnSegments(events, entries),
  };
}
