import type { TheoryVolatilityReport, TheoryVolatilityRiskLabel } from "@/types/theory";

const STORAGE_KEY = "voicememory_theory_volatility";
const STATE_VERSION = 1;
const MAX_VISITS = 80;
const STALE_AFTER_DAYS = 14;

export const THEORY_VOLATILITY_RISK_LABELS: Record<TheoryVolatilityRiskLabel, string> = {
  healthy: "Healthy",
  quiet: "Quiet",
  stale: "Stale",
  dead_feed_risk: "Dead feed risk",
};

export interface TheoryVolatilityVisitRecord {
  at: string;
  sessionNumber: number;
  totalTheories: number;
  strengthenedCount: number;
  weakenedCount: number;
  resolvedCount: number;
  retiredCount: number;
  theoryChangeCount: number;
  evidenceMovementCount: number;
  zeroMovement: boolean;
  hadBaseline: boolean;
}

export interface TheoryVolatilityState {
  version: number;
  updatedAt: string;
  firstDiscoverAt: string | null;
  lastChangeAt: string | null;
  peakTheoriesGenerated: number;
  cumulativeStrengthened: number;
  cumulativeWeakened: number;
  cumulativeResolved: number;
  cumulativeRetired: number;
  zeroMovementVisits: number;
  discoverVisitCount: number;
  staleZeroMovementSessions: number;
  staleSessionIds: number[];
  visits: TheoryVolatilityVisitRecord[];
}

export interface RecordDiscoverVolatilityInput {
  totalTheories: number;
  strengthenedCount: number;
  weakenedCount: number;
  resolvedCount: number;
  retiredCount: number;
  theoryChangeCount: number;
  evidenceMovementCount: number;
  hasBaseline: boolean;
}

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readLocalSessionNumber(): number {
  try {
    const store =
      typeof sessionStorage !== "undefined"
        ? sessionStorage
        : (globalThis as { sessionStorage?: Storage }).sessionStorage;
    if (store) {
      const n = Number(store.getItem("voicememory_app_session_count") ?? "0");
      if (Number.isFinite(n) && n > 0) return n;
    }
  } catch {
    /* ignore */
  }
  return 0;
}

function emptyState(): TheoryVolatilityState {
  const now = new Date().toISOString();
  return {
    version: STATE_VERSION,
    updatedAt: now,
    firstDiscoverAt: null,
    lastChangeAt: null,
    peakTheoriesGenerated: 0,
    cumulativeStrengthened: 0,
    cumulativeWeakened: 0,
    cumulativeResolved: 0,
    cumulativeRetired: 0,
    zeroMovementVisits: 0,
    discoverVisitCount: 0,
    staleZeroMovementSessions: 0,
    staleSessionIds: [],
    visits: [],
  };
}

function normalizeState(raw: unknown): TheoryVolatilityState {
  if (!raw || typeof raw !== "object") return emptyState();
  const row = raw as Partial<TheoryVolatilityState>;
  const visits = Array.isArray(row.visits)
    ? row.visits.filter((v): v is TheoryVolatilityVisitRecord => {
        return Boolean(v && typeof v === "object" && typeof (v as TheoryVolatilityVisitRecord).at === "string");
      })
    : [];

  return {
    version: typeof row.version === "number" ? row.version : STATE_VERSION,
    updatedAt: typeof row.updatedAt === "string" ? row.updatedAt : new Date().toISOString(),
    firstDiscoverAt:
      typeof row.firstDiscoverAt === "string" ? row.firstDiscoverAt : null,
    lastChangeAt: typeof row.lastChangeAt === "string" ? row.lastChangeAt : null,
    peakTheoriesGenerated:
      typeof row.peakTheoriesGenerated === "number" ? row.peakTheoriesGenerated : 0,
    cumulativeStrengthened:
      typeof row.cumulativeStrengthened === "number" ? row.cumulativeStrengthened : 0,
    cumulativeWeakened:
      typeof row.cumulativeWeakened === "number" ? row.cumulativeWeakened : 0,
    cumulativeResolved:
      typeof row.cumulativeResolved === "number" ? row.cumulativeResolved : 0,
    cumulativeRetired: typeof row.cumulativeRetired === "number" ? row.cumulativeRetired : 0,
    zeroMovementVisits:
      typeof row.zeroMovementVisits === "number" ? row.zeroMovementVisits : 0,
    discoverVisitCount:
      typeof row.discoverVisitCount === "number" ? row.discoverVisitCount : 0,
    staleZeroMovementSessions:
      typeof row.staleZeroMovementSessions === "number"
        ? row.staleZeroMovementSessions
        : 0,
    staleSessionIds: Array.isArray(row.staleSessionIds)
      ? row.staleSessionIds.filter((n): n is number => typeof n === "number")
      : [],
    visits: visits.slice(-MAX_VISITS),
  };
}

export function readTheoryVolatilityState(): TheoryVolatilityState {
  const store = getStorage();
  if (!store) return emptyState();
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return emptyState();
    return normalizeState(JSON.parse(raw));
  } catch {
    return emptyState();
  }
}

function writeTheoryVolatilityState(state: TheoryVolatilityState): void {
  const store = getStorage();
  if (!store) return;
  store.setItem(
    STORAGE_KEY,
    JSON.stringify({
      ...state,
      visits: state.visits.slice(-MAX_VISITS),
      staleSessionIds: state.staleSessionIds.slice(-40),
    }),
  );
}

function daysBetween(aIso: string, bIso: string): number {
  const a = new Date(aIso).getTime();
  const b = new Date(bIso).getTime();
  return Math.abs(b - a) / (1000 * 60 * 60 * 24);
}

function daysSince(iso: string | null): number | null {
  if (!iso) return null;
  return daysBetween(iso, new Date().toISOString());
}

function movementEventCount(input: RecordDiscoverVolatilityInput): number {
  return (
    input.strengthenedCount +
    input.weakenedCount +
    input.theoryChangeCount +
    input.evidenceMovementCount +
    input.resolvedCount +
    input.retiredCount
  );
}

/** Record one discover open sample for local volatility measurement. */
export function recordDiscoverVolatilitySample(
  input: RecordDiscoverVolatilityInput,
): TheoryVolatilityState {
  const now = new Date().toISOString();
  const state = readTheoryVolatilityState();
  const sessionNumber = readLocalSessionNumber();

  const zeroMovement =
    input.hasBaseline &&
    input.theoryChangeCount === 0 &&
    input.evidenceMovementCount === 0;

  const hadMovement = movementEventCount(input) > 0;

  const visit: TheoryVolatilityVisitRecord = {
    at: now,
    sessionNumber,
    totalTheories: input.totalTheories,
    strengthenedCount: input.strengthenedCount,
    weakenedCount: input.weakenedCount,
    resolvedCount: input.resolvedCount,
    retiredCount: input.retiredCount,
    theoryChangeCount: input.theoryChangeCount,
    evidenceMovementCount: input.evidenceMovementCount,
    zeroMovement,
    hadBaseline: input.hasBaseline,
  };

  const next: TheoryVolatilityState = {
    ...state,
    updatedAt: now,
    firstDiscoverAt: state.firstDiscoverAt ?? now,
    lastChangeAt: hadMovement ? now : state.lastChangeAt,
    peakTheoriesGenerated: Math.max(state.peakTheoriesGenerated, input.totalTheories),
    cumulativeStrengthened: state.cumulativeStrengthened + input.strengthenedCount,
    cumulativeWeakened: state.cumulativeWeakened + input.weakenedCount,
    cumulativeResolved: state.cumulativeResolved + input.resolvedCount,
    cumulativeRetired: state.cumulativeRetired + input.retiredCount,
    zeroMovementVisits: state.zeroMovementVisits + (zeroMovement ? 1 : 0),
    discoverVisitCount: state.discoverVisitCount + 1,
    visits: [...state.visits, visit].slice(-MAX_VISITS),
    staleZeroMovementSessions: state.staleZeroMovementSessions,
    staleSessionIds: [...state.staleSessionIds],
  };

  const daysSinceFirst = daysSince(next.firstDiscoverAt);
  if (
    zeroMovement &&
    input.hasBaseline &&
    daysSinceFirst !== null &&
    daysSinceFirst >= STALE_AFTER_DAYS &&
    sessionNumber > 0 &&
    !next.staleSessionIds.includes(sessionNumber)
  ) {
    next.staleSessionIds.push(sessionNumber);
    next.staleZeroMovementSessions += 1;
  }

  writeTheoryVolatilityState(next);
  return next;
}

function intervalsBetweenMovementVisits(visits: TheoryVolatilityVisitRecord[]): number[] {
  const movementTimes = visits
    .filter((v) => v.hadBaseline && !v.zeroMovement)
    .map((v) => v.at);

  if (movementTimes.length < 2) return [];

  const gaps: number[] = [];
  for (let i = 1; i < movementTimes.length; i += 1) {
    gaps.push(daysBetween(movementTimes[i - 1]!, movementTimes[i]!));
  }
  return gaps;
}

function median(values: number[]): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return Math.round(((sorted[mid - 1]! + sorted[mid]!) / 2) * 10) / 10;
  }
  return Math.round(sorted[mid]! * 10) / 10;
}

function average(values: number[]): number | null {
  if (values.length === 0) return null;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

export function classifyTheoryVolatilityRisk(input: {
  daysSinceLastChange: number | null;
  zeroMovementVisitRate: number;
  staleZeroMovementSessions: number;
  cumulativeMovementEvents: number;
  discoverVisitCount: number;
  lastVisitHadZeroMovement: boolean;
}): TheoryVolatilityRiskLabel {
  const daysSince = input.daysSinceLastChange;

  if (
    input.staleZeroMovementSessions >= 1 ||
    (daysSince !== null &&
      daysSince >= STALE_AFTER_DAYS &&
      input.lastVisitHadZeroMovement)
  ) {
    return "dead_feed_risk";
  }

  if (
    daysSince !== null &&
    daysSince >= 10 &&
    input.zeroMovementVisitRate >= 40
  ) {
    return "stale";
  }

  if (
    input.cumulativeMovementEvents >= 4 &&
    input.zeroMovementVisitRate < 45 &&
    (daysSince === null || daysSince < 10)
  ) {
    return "healthy";
  }

  if (input.zeroMovementVisitRate >= 55 || (daysSince !== null && daysSince >= 5)) {
    return "quiet";
  }

  if (input.discoverVisitCount <= 2) return "quiet";

  return input.cumulativeMovementEvents >= 2 ? "healthy" : "quiet";
}

function buildInsightLines(report: Omit<TheoryVolatilityReport, "insightLines" | "generatedAt">): string[] {
  const lines: string[] = [];

  lines.push(
    `Discover visits: ${report.discoverVisitCount} (${report.zeroMovementVisits} with zero movement).`,
  );

  if (report.daysSinceLastChange !== null) {
    lines.push(`Last feed movement was ${report.daysSinceLastChange} day(s) ago.`);
  } else {
    lines.push("No theory or evidence movement recorded on discover yet.");
  }

  if (report.averageDaysBetweenChanges !== null) {
    lines.push(
      `Average ${report.averageDaysBetweenChanges} day(s) between movement visits.`,
    );
  }

  if (report.staleZeroMovementSessions > 0) {
    lines.push(
      `${report.staleZeroMovementSessions} local session(s) opened discover with zero movement after ${STALE_AFTER_DAYS}+ days.`,
    );
  }

  lines.push(`Risk read: ${report.riskLabelDisplay}.`);

  return lines.slice(0, 5);
}

/** Build volatility readout from persisted local discover samples. */
export function buildTheoryVolatilityReport(): TheoryVolatilityReport {
  const state = readTheoryVolatilityState();
  const baselineVisits = state.visits.filter((v) => v.hadBaseline);
  const lastVisit = state.visits[state.visits.length - 1];
  const gaps = intervalsBetweenMovementVisits(state.visits);

  const zeroMovementVisitRate =
    baselineVisits.length > 0
      ? Math.round((state.zeroMovementVisits / baselineVisits.length) * 100)
      : 0;

  const cumulativeMovementEvents =
    state.cumulativeStrengthened +
    state.cumulativeWeakened +
    state.cumulativeResolved +
    state.cumulativeRetired;

  const daysSinceLastChange = daysSince(state.lastChangeAt);

  const riskLabel = classifyTheoryVolatilityRisk({
    daysSinceLastChange,
    zeroMovementVisitRate,
    staleZeroMovementSessions: state.staleZeroMovementSessions,
    cumulativeMovementEvents,
    discoverVisitCount: state.discoverVisitCount,
    lastVisitHadZeroMovement: lastVisit?.zeroMovement ?? false,
  });

  const core = {
    riskLabel,
    riskLabelDisplay: THEORY_VOLATILITY_RISK_LABELS[riskLabel],
    totalTheoriesGenerated: state.peakTheoriesGenerated,
    strengthenedCount: state.cumulativeStrengthened,
    weakenedCount: state.cumulativeWeakened,
    resolvedCount: state.cumulativeResolved,
    retiredCount: state.cumulativeRetired,
    averageDaysBetweenChanges: average(gaps),
    medianDaysBetweenChanges: median(gaps),
    daysSinceLastChange,
    discoverVisitCount: state.discoverVisitCount,
    zeroMovementVisits: state.zeroMovementVisits,
    zeroMovementVisitRate,
    staleZeroMovementSessions: state.staleZeroMovementSessions,
    cumulativeMovementEvents,
    lastVisitHadZeroMovement: lastVisit?.zeroMovement ?? false,
  };

  return {
    generatedAt: new Date().toISOString(),
    ...core,
    insightLines: buildInsightLines(core),
  };
}

export function clearTheoryVolatilityForEval(): void {
  getStorage()?.removeItem(STORAGE_KEY);
}
