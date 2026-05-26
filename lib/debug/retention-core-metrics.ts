import { readLocalEvents } from "@/lib/local-analytics";
import {
  computeMagicMomentMetrics,
  MAGIC_MOMENT_EVENTS,
} from "@/lib/retention/first-magic-moment";
import { computeRecurrenceDensityMetrics } from "@/lib/retention/recurrence-density";
import { RETURN_TRIGGER_EVENTS } from "@/lib/retention/return-triggers";
import {
  assessResurfacingConfidence,
  collectResurfacingConfidenceCandidates,
} from "@/lib/revisit/resurfacing-confidence";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { RecurrenceDensityMetrics } from "@/types/recurrence-density";

const FUNNEL_STATE_KEY = "voicememory_first_week_funnel";
const MAGIC_CONFIRMED_KEY = "voicememory_first_magic_confirmed";

const MS_HOUR = 60 * 60 * 1000;
const MS_DAY = 24 * MS_HOUR;

const FUNNEL_LINEAR_STAGES = [
  "first_visit",
  "recorder_viewed",
  "first_reflection_saved",
  "second_reflection_saved",
  "first_resurfacing_candidate",
  "first_magic_moment",
  "return_within_24h",
  "return_within_7d",
] as const;

const FUNNEL_STAGE_LABELS: Record<string, string> = {
  first_visit: "First visit",
  onboarding_completed: "Onboarding completed",
  onboarding_skipped: "Onboarding skipped",
  recorder_viewed: "Recorder viewed",
  first_reflection_saved: "First reflection saved",
  second_reflection_saved: "Second reflection saved",
  first_resurfacing_candidate: "First resurfacing candidate",
  first_magic_moment: "First magic moment",
  return_within_24h: "Return within 24h",
  return_within_7d: "Return within 7d",
};

const RETURN_AFTER_MAGIC_EVENTS = new Set<string>([
  ...Object.values(RETURN_TRIGGER_EVENTS),
  CALLBACK_LEARNING_EVENTS.returnAfter,
  MAGIC_MOMENT_EVENTS.returnAfterCallback,
  "return_within_24h",
  "return_within_7d",
]);

export interface RetentionCoreFunnelStageRow {
  stage: string;
  label: string;
  reached: boolean;
  at: string | null;
}

export interface RetentionCoreFunnelMetrics {
  stages: RetentionCoreFunnelStageRow[];
  dropOffStage: string | null;
  dropOffLabel: string | null;
  linearStagesReached: number;
  linearStagesTotal: number;
  linearCompletionRate: number;
}

export interface RetentionCoreMagicMetrics {
  timeToFirstMagicMs: number | null;
  percentReachingMagic: number;
  reachedMagic: boolean;
  firstMagicConfirmedAt: string | null;
  d1ReturnAfterMagic: boolean | null;
  d7ReturnAfterMagic: boolean | null;
}

export interface RetentionCoreResurfacingMetrics {
  averageConfidence: number | null;
  openRate: number;
  rereadRate: number;
  reflectionAfterCallbackRate: number;
  suppressionRate: number;
  weakCallbackExposureRate: number;
  callbacksShown: number;
  callbacksOpened: number;
  callbacksReread: number;
  reflectionAfterCallback: number;
}

export interface RetentionCoreMetricsReport {
  generatedAt: string;
  hasData: boolean;
  scopeNote: string;
  magic: RetentionCoreMagicMetrics;
  resurfacing: RetentionCoreResurfacingMetrics;
  recurrence: RecurrenceDensityMetrics;
  funnel: RetentionCoreFunnelMetrics;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function ratePercent(numerator: number, denominator: number): number {
  if (denominator === 0) return 0;
  return Math.round((numerator / denominator) * 100);
}

function firstReflectionAtMs(entries: ReturnType<typeof getMemoryEligibleEntries>): number | null {
  if (entries.length === 0) return null;
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  return new Date(sorted[0].createdAt).getTime();
}

function readMagicConfirmedAt(): string | null {
  if (!isBrowser()) return null;
  try {
    const raw = localStorage.getItem(MAGIC_CONFIRMED_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { at?: string };
    return parsed.at ?? null;
  } catch {
    return null;
  }
}

function readFunnelStageTimestamps(): Map<string, string> {
  const map = new Map<string, string>();
  if (!isBrowser()) return map;

  try {
    const raw = localStorage.getItem(FUNNEL_STATE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as {
        stages?: Record<string, { at?: string }>;
      };
      for (const [stage, row] of Object.entries(parsed.stages ?? {})) {
        if (row?.at) map.set(stage, row.at);
      }
    }
  } catch {
    // ignore corrupt funnel state
  }

  const funnelNames = new Set<string>([
    ...FUNNEL_LINEAR_STAGES,
    "onboarding_completed",
    "onboarding_skipped",
  ]);

  for (const event of readLocalEvents()) {
    if (!funnelNames.has(event.name)) continue;
    if (!map.has(event.name)) {
      map.set(event.name, event.at);
    }
  }

  return map;
}

function buildFunnelMetrics(): RetentionCoreFunnelMetrics {
  const timestamps = readFunnelStageTimestamps();
  const stages: RetentionCoreFunnelStageRow[] = FUNNEL_LINEAR_STAGES.map((stage) => ({
    stage,
    label: FUNNEL_STAGE_LABELS[stage] ?? stage,
    reached: timestamps.has(stage),
    at: timestamps.get(stage) ?? null,
  }));

  const reachedCount = stages.filter((row) => row.reached).length;
  const dropOff = stages.find((row) => !row.reached) ?? null;

  return {
    stages,
    dropOffStage: dropOff?.stage ?? null,
    dropOffLabel: dropOff?.label ?? null,
    linearStagesReached: reachedCount,
    linearStagesTotal: FUNNEL_LINEAR_STAGES.length,
    linearCompletionRate: ratePercent(reachedCount, FUNNEL_LINEAR_STAGES.length),
  };
}

function countCallbackEvents(events: ReturnType<typeof readLocalEvents>) {
  const shownNoteIds = new Set<string>();
  const openedNoteIds = new Set<string>();
  let shown = 0;
  let opened = 0;
  let reread = 0;
  let reflectionAfter = 0;

  for (const event of events) {
    const noteId = event.meta?.noteId;
    switch (event.name) {
      case CALLBACK_LEARNING_EVENTS.shown:
        shown += 1;
        if (noteId) shownNoteIds.add(noteId);
        break;
      case CALLBACK_LEARNING_EVENTS.opened:
        opened += 1;
        if (noteId) openedNoteIds.add(noteId);
        break;
      case CALLBACK_LEARNING_EVENTS.reread:
        reread += 1;
        break;
      case CALLBACK_LEARNING_EVENTS.reflectionAfter:
        reflectionAfter += 1;
        break;
      default:
        break;
    }
  }

  const openedAmongShown = [...openedNoteIds].filter((id) => shownNoteIds.has(id)).length;

  return {
    shown,
    opened,
    reread,
    reflectionAfter,
    uniqueShown: shownNoteIds.size,
    uniqueOpenedAmongShown: openedAmongShown,
    shownNoteIds: [...shownNoteIds],
  };
}

function buildResurfacingMetrics(
  entries: ReturnType<typeof getMemoryEligibleEntries>,
  events: ReturnType<typeof readLocalEvents>,
): RetentionCoreResurfacingMetrics {
  const candidates = collectResurfacingConfidenceCandidates(entries);
  const verdicts = candidates.map((note) => assessResurfacingConfidence(note, entries));

  const averageConfidence =
    verdicts.length === 0
      ? null
      : Math.round(
          verdicts.reduce((sum, verdict) => sum + verdict.totalConfidence, 0) / verdicts.length,
        );

  const suppressed = verdicts.filter((verdict) => verdict.classification === "suppress").length;
  const suppressionRate = ratePercent(suppressed, verdicts.length);

  const callbackCounts = countCallbackEvents(events);

  const noteById = new Map(candidates.map((note) => [note.id, note]));
  let weakShown = 0;
  for (const noteId of callbackCounts.shownNoteIds) {
    const note = noteById.get(noteId);
    if (!note) continue;
    if (assessResurfacingConfidence(note, entries).classification === "weak") {
      weakShown += 1;
    }
  }
  const weakCallbackExposureRate = ratePercent(weakShown, callbackCounts.uniqueShown);

  return {
    averageConfidence,
    openRate: ratePercent(callbackCounts.uniqueOpenedAmongShown, callbackCounts.uniqueShown),
    rereadRate: ratePercent(callbackCounts.reread, callbackCounts.opened),
    reflectionAfterCallbackRate: ratePercent(
      callbackCounts.reflectionAfter,
      callbackCounts.opened,
    ),
    suppressionRate,
    weakCallbackExposureRate,
    callbacksShown: callbackCounts.shown,
    callbacksOpened: callbackCounts.opened,
    callbacksReread: callbackCounts.reread,
    reflectionAfterCallback: callbackCounts.reflectionAfter,
  };
}

function hasReturnAfterMagic(magicAtIso: string, maxMs: number): boolean {
  const magicMs = new Date(magicAtIso).getTime();
  if (Number.isNaN(magicMs)) return false;

  return readLocalEvents().some((event) => {
    if (!RETURN_AFTER_MAGIC_EVENTS.has(event.name)) return false;
    const delta = new Date(event.at).getTime() - magicMs;
    return delta >= MS_HOUR && delta <= maxMs;
  });
}

function buildMagicMetrics(
  entries: ReturnType<typeof getMemoryEligibleEntries>,
): RetentionCoreMagicMetrics {
  const magicMetrics = computeMagicMomentMetrics(entries);
  const confirmedAt = magicMetrics.firstMagicConfirmedAt ?? readMagicConfirmedAt();
  const reflectionAt = firstReflectionAtMs(entries);

  const events = readLocalEvents();
  const firstShown = events.find((event) => event.name === MAGIC_MOMENT_EVENTS.candidateShown);

  let timeToFirstMagicMs = magicMetrics.timeUntilFirstMeaningfulCallbackMs;
  if (confirmedAt && reflectionAt !== null) {
    timeToFirstMagicMs = Math.max(0, new Date(confirmedAt).getTime() - reflectionAt);
  } else if (firstShown && reflectionAt !== null && timeToFirstMagicMs === null) {
    timeToFirstMagicMs = Math.max(0, new Date(firstShown.at).getTime() - reflectionAt);
  }

  const funnelTimestamps = readFunnelStageTimestamps();
  const reachedMagic =
    confirmedAt !== null ||
    funnelTimestamps.has("first_magic_moment") ||
    events.some((event) => event.name === MAGIC_MOMENT_EVENTS.candidateShown);

  const magicAnchor = confirmedAt ?? firstShown?.at ?? null;

  return {
    timeToFirstMagicMs,
    percentReachingMagic: reachedMagic ? 100 : 0,
    reachedMagic,
    firstMagicConfirmedAt: confirmedAt,
    d1ReturnAfterMagic: magicAnchor ? hasReturnAfterMagic(magicAnchor, MS_DAY) : null,
    d7ReturnAfterMagic: magicAnchor ? hasReturnAfterMagic(magicAnchor, 7 * MS_DAY) : null,
  };
}

/** Internal retention dashboard — single-device local cohort only. */
export function buildRetentionCoreMetricsReport(): RetentionCoreMetricsReport {
  const entries = getMemoryEligibleEntries();
  const events = readLocalEvents();
  const hasData =
    entries.length > 0 ||
    events.length > 0 ||
    readFunnelStageTimestamps().size > 0;

  return {
    generatedAt: new Date().toISOString(),
    hasData,
    scopeNote:
      "This device only — rates are 0–100% for this browser, not a multi-user cohort.",
    magic: buildMagicMetrics(entries),
    resurfacing: buildResurfacingMetrics(entries, events),
    recurrence: computeRecurrenceDensityMetrics(entries),
    funnel: buildFunnelMetrics(),
  };
}

export function formatRetentionCoreDuration(ms: number | null): string {
  if (ms === null) return "—";
  if (ms < MS_HOUR) return `${Math.round(ms / 1000)}s`;
  if (ms < MS_DAY) return `${Math.round(ms / MS_HOUR)}h`;
  return `${Math.round(ms / MS_DAY)}d`;
}

export function formatRetentionCoreRate(value: number | null): string {
  if (value === null) return "—";
  return `${value}%`;
}

export function formatRetentionCoreBoolean(value: boolean | null): string {
  if (value === null) return "—";
  return value ? "Yes" : "No";
}
