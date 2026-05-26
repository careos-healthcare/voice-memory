import { readLocalEvents } from "@/lib/local-analytics";
import { CLARITY_EVENTS } from "@/lib/clarity/clarity-observation";
import { REFLEX_EVENTS } from "@/lib/reflex/reflex-observation";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { detectThinkingOutLoudSignals } from "@/lib/clarity/thinking-out-loud-signals";
import type { ReflexScoreSnapshot } from "@/types/reflex";

function ratePercent(num: number, denom: number): number {
  if (denom <= 0) return 0;
  return Math.round((num / denom) * 100);
}

function medianLatencyMs(eventName: string, field: string): number | null {
  const values = readLocalEvents()
    .filter((e) => e.name === eventName && e.meta?.[field])
    .map((e) => Number(e.meta?.[field]))
    .filter((n) => Number.isFinite(n) && n > 0 && n < 120_000);
  if (values.length === 0) return null;
  values.sort((a, b) => a - b);
  return values[Math.floor(values.length / 2)] ?? null;
}

/** Behavior that favors speaking — not engagement time or scroll depth. */
export function buildReflexScoreSnapshot(): ReflexScoreSnapshot {
  const events = readLocalEvents();
  const entries = getMemoryEligibleEntries();

  const shown = events.filter((e) => e.name === CALLBACK_LEARNING_EVENTS.shown).length;
  const immediate = events.filter(
    (e) =>
      e.name === REFLEX_EVENTS.recordingStartedLatency ||
      e.name === CALLBACK_LEARNING_EVENTS.reflectionAfter,
  ).length;
  const resurfacingToImmediateRecord = ratePercent(immediate, Math.max(shown, 1));

  const loopResurface = events.filter(
    (e) => e.name === OPEN_LOOP_EVENTS.resurfacingShown,
  ).length;
  const loopReflect = events.filter(
    (e) => e.name === OPEN_LOOP_EVENTS.reflectionAfterResurface,
  ).length;
  const unresolvedReturnScore = ratePercent(loopReflect, Math.max(loopResurface, 1));

  const landToRecord = medianLatencyMs(
    REFLEX_EVENTS.recordingStartedLatency,
    "landToRecordMs",
  );
  const speedToSpeakScore =
    landToRecord == null
      ? 0
      : landToRecord <= 8000
        ? 90
        : landToRecord <= 20000
          ? 55
          : 25;

  const gaps: number[] = [];
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  for (let i = 1; i < sorted.length; i += 1) {
    const gap =
      (new Date(sorted[i].createdAt).getTime() -
        new Date(sorted[i - 1].createdAt).getTime()) /
      (1000 * 60 * 60);
    if (gap > 0 && gap < 168) gaps.push(gap);
  }
  const emotionalRecurrenceTiming =
    gaps.length === 0
      ? 0
      : Math.min(100, Math.round(72 - Math.min(40, gaps[gaps.length - 1] ?? 72)));

  const lateNightReflex = events.filter((e) => {
    if (e.name !== REFLEX_EVENTS.reflexMomentDetected) return false;
    return e.meta?.triggerType === "late_night";
  }).length;
  const lateNightReflexUsage = Math.min(100, lateNightReflex * 25);

  let conflictEntries = 0;
  let conflictFollowups = 0;
  for (const entry of entries.slice(-12)) {
    if (detectThinkingOutLoudSignals(entry.transcript).conflictLikely) {
      conflictEntries += 1;
    }
  }
  conflictFollowups = events.filter(
    (e) =>
      e.name === CLARITY_EVENTS.followupSaved ||
      e.name === CALLBACK_LEARNING_EVENTS.reflectionAfter,
  ).length;
  const conflictRepeatScore = ratePercent(
    conflictFollowups,
    Math.max(conflictEntries, 1),
  );

  const overall = Math.round(
    resurfacingToImmediateRecord * 0.28 +
      unresolvedReturnScore * 0.2 +
      speedToSpeakScore * 0.28 +
      emotionalRecurrenceTiming * 0.12 +
      conflictRepeatScore * 0.12,
  );

  return {
    resurfacingToImmediateRecord,
    unresolvedReturnScore,
    speedToSpeakScore,
    emotionalRecurrenceTiming,
    lateNightReflexUsage,
    conflictRepeatScore,
    overall,
  };
}
