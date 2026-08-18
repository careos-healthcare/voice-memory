import { readLocalEvents } from "@/lib/local-analytics";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import {
  getResurfacingFatigueRecords,
  type ResurfacingBehavioralFatigueRecord,
} from "@/lib/resurfacing/resurfacing-fatigue";
import { ONBOARDING_CLARITY_EVENTS } from "@/lib/onboarding/onboarding-observation";
import type {
  ReflectionFrictionReport,
  ReflectionFrictionWarning,
} from "@/types/reflection-friction";

const SURFACES_KEY = "voicememory_surfaces_before_recording";
const RETURN_OPENED_KEY = "voicememory_return_recorder_opened_at";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function recordSurfaceBeforeRecording(): void {
  if (!isBrowser()) return;
  const count = Number(sessionStorage.getItem(SURFACES_KEY) ?? "0") + 1;
  sessionStorage.setItem(SURFACES_KEY, String(count));
}

export function resetSurfacesBeforeRecording(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(SURFACES_KEY, "0");
}

export function readSurfacesBeforeRecording(): number {
  if (!isBrowser()) return 0;
  return Number(sessionStorage.getItem(SURFACES_KEY) ?? "0");
}

export function markReturnRecorderOpened(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(RETURN_OPENED_KEY, String(Date.now()));
}

function avgSecondsToRecord(): number | null {
  if (!isBrowser()) return null;
  const openedAt = Number(sessionStorage.getItem(RETURN_OPENED_KEY) ?? "0");
  if (!openedAt) return null;
  const started = readLocalEvents().find(
    (event) => event.name === "recorder_started",
  );
  if (!started) return null;
  const delta = (new Date(started.at).getTime() - openedAt) / 1000;
  return delta > 0 && delta < 600 ? Math.round(delta) : null;
}

function buildWarnings(
  metrics: ReflectionFrictionReport["metrics"],
  fatigue: ResurfacingBehavioralFatigueRecord[],
): ReflectionFrictionWarning[] {
  const warnings: ReflectionFrictionWarning[] = [];

  if (metrics.surfacesBeforeRecording >= 3) {
    warnings.push({
      id: "too_many_surfaces",
      message: "Too many continuity surfaces before recording.",
    });
  }

  if (
    metrics.resurfacingSeen > 0 &&
    metrics.recorderOpenedFromReturn < Math.max(2, metrics.resurfacingSeen * 0.15)
  ) {
    warnings.push({
      id: "open_no_record",
      message: "Users open callbacks but do not record.",
    });
  }

  const weakFatigue = fatigue.filter(
    (row) =>
      row.ignoredCount >= 2 &&
      !row.lastReflectionAt &&
      row.repeatedDismissals === 0,
  );
  if (weakFatigue.length >= 2) {
    warnings.push({
      id: "behaviorally_weak",
      message:
        "Resurfacing may be emotionally interesting but behaviorally weak.",
    });
  }

  if (metrics.openedWithoutReflection >= 2 && metrics.reflectionSaved === 0) {
    warnings.push({
      id: "opened_without_reflection",
      message: "Callbacks open but reflections rarely follow.",
    });
  }

  return warnings;
}

export function buildReflectionFrictionReport(): ReflectionFrictionReport {
  const events = readLocalEvents();
  const fatigue = getResurfacingFatigueRecords();

  const resurfacingSeen = events.filter(
    (event) => event.name === CALLBACK_LEARNING_EVENTS.shown,
  ).length;

  const recorderOpenedFromReturn = events.filter(
    (event) =>
      event.name === CALLBACK_LEARNING_EVENTS.opened ||
      event.name === "record_return_opened",
  ).length;

  const reflectionSaved = events.filter(
    (event) => event.name === CALLBACK_LEARNING_EVENTS.reflectionAfter,
  ).length;

  const repeatDismissals = fatigue.reduce(
    (sum, row) => sum + row.repeatedDismissals,
    0,
  );
  const openedWithoutReflection = fatigue.reduce(
    (sum, row) => sum + row.openedWithoutReflection,
    0,
  );

  const recorderAbandoned = events.filter(
    (event) => event.name === ONBOARDING_CLARITY_EVENTS.recorderAbandoned,
  ).length;

  const metrics = {
    resurfacingSeen,
    recorderOpenedFromReturn,
    recorderAbandoned,
    reflectionSaved,
    avgSecondsToRecordAfterCallback: avgSecondsToRecord(),
    repeatDismissals,
    surfacesBeforeRecording: readSurfacesBeforeRecording(),
    openedWithoutReflection,
  };

  return {
    metrics,
    warnings: buildWarnings(metrics, fatigue),
  };
}
