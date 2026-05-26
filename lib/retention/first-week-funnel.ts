import {
  LAUNCH_EVENTS,
  readLocalEvents,
  trackLocalEvent,
} from "@/lib/local-analytics";
import type {
  FirstWeekFunnelEventPayload,
  FirstWeekFunnelMetrics,
  FirstWeekFunnelStage,
} from "@/types/first-week-funnel";

export const FIRST_WEEK_FUNNEL_SCHEMA_VERSION = "1" as const;

export const FIRST_WEEK_FUNNEL_EVENTS = {
  firstVisit: "first_visit",
  onboardingCompleted: "onboarding_completed",
  onboardingSkipped: "onboarding_skipped",
  recorderViewed: "recorder_viewed",
  firstReflectionSaved: "first_reflection_saved",
  secondReflectionSaved: "second_reflection_saved",
  firstResurfacingCandidate: "first_resurfacing_candidate",
  firstMagicMoment: "first_magic_moment",
  returnWithin24h: "return_within_24h",
  returnWithin7d: "return_within_7d",
} as const satisfies Record<string, FirstWeekFunnelStage>;

export const FUNNEL_STAGE_LABELS: Record<FirstWeekFunnelStage, string> = {
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

/** Linear progression after onboarding branch. */
export const FUNNEL_LINEAR_STAGES: FirstWeekFunnelStage[] = [
  "first_visit",
  "recorder_viewed",
  "first_reflection_saved",
  "second_reflection_saved",
  "first_resurfacing_candidate",
  "first_magic_moment",
  "return_within_24h",
  "return_within_7d",
];

const FUNNEL_STATE_KEY = "voicememory_first_week_funnel";
const MS_24H = 24 * 60 * 60 * 1000;
const MS_7D = 7 * MS_24H;

interface FunnelState {
  schemaVersion: typeof FIRST_WEEK_FUNNEL_SCHEMA_VERSION;
  stages: Partial<Record<FirstWeekFunnelStage, { at: string; meta?: Record<string, string> }>>;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function eventAtMs(at: string): number {
  return new Date(at).getTime();
}

function readState(): FunnelState {
  if (!isBrowser()) {
    return { schemaVersion: FIRST_WEEK_FUNNEL_SCHEMA_VERSION, stages: {} };
  }
  try {
    const raw = localStorage.getItem(FUNNEL_STATE_KEY);
    if (!raw) return { schemaVersion: FIRST_WEEK_FUNNEL_SCHEMA_VERSION, stages: {} };
    const parsed = JSON.parse(raw) as Partial<FunnelState>;
    return {
      schemaVersion: FIRST_WEEK_FUNNEL_SCHEMA_VERSION,
      stages: parsed.stages ?? {},
    };
  } catch {
    return { schemaVersion: FIRST_WEEK_FUNNEL_SCHEMA_VERSION, stages: {} };
  }
}

function writeState(state: FunnelState): void {
  if (!isBrowser()) return;
  localStorage.setItem(FUNNEL_STATE_KEY, JSON.stringify(state));
}

function buildPayload(
  stage: FirstWeekFunnelStage,
  at: string,
  meta?: Record<string, string>,
): FirstWeekFunnelEventPayload {
  return {
    schemaVersion: FIRST_WEEK_FUNNEL_SCHEMA_VERSION,
    stage,
    at,
    meta,
  };
}

/** Track a funnel stage once per device — local-only, server-ready shape. */
export function trackFunnelStage(
  stage: FirstWeekFunnelStage,
  meta?: Record<string, string>,
): boolean {
  if (!isBrowser()) return false;

  const state = readState();
  if (state.stages[stage]) return false;

  const at = new Date().toISOString();
  state.stages[stage] = { at, meta };
  writeState(state);

  trackLocalEvent(stage, {
    funnel: "first_week",
    schemaVersion: FIRST_WEEK_FUNNEL_SCHEMA_VERSION,
    ...meta,
  });

  return true;
}

export function readFunnelStageTimestamp(stage: FirstWeekFunnelStage): string | null {
  return readState().stages[stage]?.at ?? null;
}

export function hasFunnelStage(stage: FirstWeekFunnelStage): boolean {
  return Boolean(readState().stages[stage]);
}

export function listFunnelEvents(limit = 40): FirstWeekFunnelEventPayload[] {
  const funnelNames = new Set<string>(Object.values(FIRST_WEEK_FUNNEL_EVENTS));
  const fromLog = readLocalEvents()
    .filter((event) => funnelNames.has(event.name))
    .map((event) =>
      buildPayload(event.name as FirstWeekFunnelStage, event.at, event.meta),
    );

  const fromState = Object.entries(readState().stages).map(([stage, row]) =>
    buildPayload(stage as FirstWeekFunnelStage, row!.at, row!.meta),
  );

  const merged = new Map<string, FirstWeekFunnelEventPayload>();
  for (const event of [...fromLog, ...fromState]) {
    merged.set(`${event.stage}:${event.at}`, event);
  }

  return [...merged.values()]
    .sort((a, b) => eventAtMs(a.at) - eventAtMs(b.at))
    .slice(-limit);
}

function backfillFromLegacyEvents(state: FunnelState): FunnelState {
  const next = { ...state, stages: { ...state.stages } };
  const events = readLocalEvents();

  const legacyMap: Array<{ stage: FirstWeekFunnelStage; names: string[] }> = [
    { stage: "onboarding_completed", names: [LAUNCH_EVENTS.onboardingCompleted] },
    {
      stage: "first_reflection_saved",
      names: [LAUNCH_EVENTS.firstReflectionCreated, FIRST_WEEK_FUNNEL_EVENTS.firstReflectionSaved],
    },
    {
      stage: "second_reflection_saved",
      names: [LAUNCH_EVENTS.secondReflectionCreated, FIRST_WEEK_FUNNEL_EVENTS.secondReflectionSaved],
    },
    {
      stage: "first_resurfacing_candidate",
      names: ["magic_candidate_created", FIRST_WEEK_FUNNEL_EVENTS.firstResurfacingCandidate],
    },
    { stage: "first_magic_moment", names: [FIRST_WEEK_FUNNEL_EVENTS.firstMagicMoment] },
  ];

  for (const { stage, names } of legacyMap) {
    if (next.stages[stage]) continue;
    const hit = events.find((event) => names.includes(event.name));
    if (hit) next.stages[stage] = { at: hit.at, meta: hit.meta };
  }

  const confirmedRaw = localStorage.getItem("voicememory_first_magic_confirmed");
  if (!next.stages.first_magic_moment && confirmedRaw) {
    try {
      const confirmed = JSON.parse(confirmedRaw) as { at?: string };
      if (confirmed.at) {
        next.stages.first_magic_moment = { at: confirmed.at };
      }
    } catch {
      // ignore
    }
  }

  return next;
}

export function readFunnelState(): FunnelState {
  return backfillFromLegacyEvents(readState());
}

export function observeFunnelFirstVisit(): void {
  trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.firstVisit);
}

export function observeFunnelOnboardingCompleted(meta?: Record<string, string>): void {
  trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.onboardingCompleted, meta);
}

export function observeFunnelOnboardingSkipped(meta?: Record<string, string>): void {
  trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.onboardingSkipped, meta);
}

export function observeFunnelRecorderViewed(meta?: Record<string, string>): void {
  trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.recorderViewed, meta);
}

export function observeFunnelReflectionSaved(totalAfterSave: number): void {
  if (totalAfterSave >= 1) {
    trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.firstReflectionSaved, {
      totalAfterSave: String(totalAfterSave),
    });
  }
  if (totalAfterSave >= 2) {
    trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.secondReflectionSaved, {
      totalAfterSave: String(totalAfterSave),
    });
  }
}

export function observeFunnelFirstResurfacingCandidate(meta?: Record<string, string>): void {
  trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.firstResurfacingCandidate, meta);
}

export function observeFunnelFirstMagicMoment(meta?: Record<string, string>): void {
  trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.firstMagicMoment, meta);
}

/** Mark return milestones relative to first visit — internal only. */
export function observeFunnelReturnVisit(hoursSinceLastOpen: number): void {
  if (hoursSinceLastOpen < 1) return;

  const firstVisitAt = readFunnelStageTimestamp(FIRST_WEEK_FUNNEL_EVENTS.firstVisit);
  if (!firstVisitAt) return;

  const msSinceFirstVisit = Date.now() - eventAtMs(firstVisitAt);
  if (msSinceFirstVisit <= MS_24H) {
    trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.returnWithin24h, {
      hoursSinceLastOpen: String(Math.round(hoursSinceLastOpen)),
    });
  }
  if (msSinceFirstVisit <= MS_7D) {
    trackFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.returnWithin7d, {
      hoursSinceLastOpen: String(Math.round(hoursSinceLastOpen)),
    });
  }
}

function resolveCurrentStage(state: FunnelState): FirstWeekFunnelStage | null {
  const allStages = Object.keys(FUNNEL_STAGE_LABELS) as FirstWeekFunnelStage[];
  let latest: FirstWeekFunnelStage | null = null;
  let latestMs = 0;

  for (const stage of allStages) {
    const at = state.stages[stage]?.at;
    if (!at) continue;
    const ms = eventAtMs(at);
    if (ms >= latestMs) {
      latestMs = ms;
      latest = stage;
    }
  }

  return latest;
}

function resolveDeepestLinearStage(state: FunnelState): FirstWeekFunnelStage | null {
  let deepest: FirstWeekFunnelStage | null = null;
  for (const stage of FUNNEL_LINEAR_STAGES) {
    if (state.stages[stage]) deepest = stage;
  }
  if (
    !state.stages.onboarding_completed &&
    !state.stages.onboarding_skipped &&
    !deepest
  ) {
    return state.stages.first_visit ? "first_visit" : null;
  }
  return deepest;
}

function msBetween(from: string | null, to: string | null): number | null {
  if (!from || !to) return null;
  return Math.max(0, eventAtMs(to) - eventAtMs(from));
}

export function computeFunnelMetrics(state: FunnelState = readFunnelState()): FirstWeekFunnelMetrics {
  const firstVisit = state.stages.first_visit?.at ?? null;
  const firstReflection = state.stages.first_reflection_saved?.at ?? null;
  const resurfacing = state.stages.first_resurfacing_candidate?.at ?? null;
  const magic = state.stages.first_magic_moment?.at ?? null;
  const return24 = state.stages.return_within_24h?.at ?? null;
  const return7 = state.stages.return_within_7d?.at ?? null;

  const reachedCount = Object.keys(state.stages).length;

  return {
    currentStage: resolveCurrentStage(state),
    deepestLinearStage: resolveDeepestLinearStage(state),
    stagesReached: reachedCount,
    msFromFirstVisitToFirstReflection: msBetween(firstVisit, firstReflection),
    msFromFirstReflectionToResurfacing: msBetween(firstReflection, resurfacing),
    msFromFirstReflectionToMagicMoment: msBetween(firstReflection, magic),
    msFromFirstVisitToReturn24h: msBetween(firstVisit, return24),
    msFromFirstVisitToReturn7d: msBetween(firstVisit, return7),
  };
}

export function buildFunnelStageRows(state: FunnelState = readFunnelState()) {
  const order: FirstWeekFunnelStage[] = [
    "first_visit",
    "onboarding_completed",
    "onboarding_skipped",
    "recorder_viewed",
    "first_reflection_saved",
    "second_reflection_saved",
    "first_resurfacing_candidate",
    "first_magic_moment",
    "return_within_24h",
    "return_within_7d",
  ];

  return order.map((stage) => ({
    stage,
    label: FUNNEL_STAGE_LABELS[stage],
    at: state.stages[stage]?.at ?? null,
    reached: Boolean(state.stages[stage]),
  }));
}

export function buildFunnelConversions(state: FunnelState = readFunnelState()) {
  const pairs: Array<[FirstWeekFunnelStage, FirstWeekFunnelStage]> = [
    ["first_visit", "recorder_viewed"],
    ["recorder_viewed", "first_reflection_saved"],
    ["first_reflection_saved", "second_reflection_saved"],
    ["first_reflection_saved", "first_resurfacing_candidate"],
    ["first_resurfacing_candidate", "first_magic_moment"],
    ["first_magic_moment", "return_within_24h"],
    ["first_magic_moment", "return_within_7d"],
  ];

  return pairs.map(([from, to]) => {
    const fromReached = Boolean(state.stages[from]);
    const toReached = Boolean(state.stages[to]);
    const rate = fromReached && toReached ? 100 : 0;
    return { from, to, rate, reached: toReached };
  });
}
