import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";

const METRICS_KEY = "voicememory_first_return_metrics";
const RERECORD_WINDOW_MS = 10 * 60 * 1000;

export type FirstReturnMetrics = {
  firstReturnShownAt: string | null;
  firstReturnOpenedAt: string | null;
  rerecordWithin10MinAt: string | null;
};

const EMPTY: FirstReturnMetrics = {
  firstReturnShownAt: null,
  firstReturnOpenedAt: null,
  rerecordWithin10MinAt: null,
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readMetrics(): FirstReturnMetrics {
  if (!isBrowser()) return { ...EMPTY };
  try {
    const raw = localStorage.getItem(METRICS_KEY);
    if (!raw) return { ...EMPTY };
    const parsed = JSON.parse(raw) as Partial<FirstReturnMetrics>;
    return {
      firstReturnShownAt:
        typeof parsed.firstReturnShownAt === "string" ? parsed.firstReturnShownAt : null,
      firstReturnOpenedAt:
        typeof parsed.firstReturnOpenedAt === "string" ? parsed.firstReturnOpenedAt : null,
      rerecordWithin10MinAt:
        typeof parsed.rerecordWithin10MinAt === "string"
          ? parsed.rerecordWithin10MinAt
          : null,
    };
  } catch {
    return { ...EMPTY };
  }
}

function writeMetrics(metrics: FirstReturnMetrics): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  localStorage.setItem(METRICS_KEY, JSON.stringify(metrics));
}

/** Local-only — whether resurfacing preceded a quick rerecord. */
export function getFirstReturnMetrics(): FirstReturnMetrics {
  return readMetrics();
}

export function recordFirstReturnShown(): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  const metrics = readMetrics();
  writeMetrics({
    ...metrics,
    firstReturnShownAt: new Date().toISOString(),
    rerecordWithin10MinAt: null,
  });
}

export function recordFirstReturnOpened(): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  const metrics = readMetrics();
  writeMetrics({
    ...metrics,
    firstReturnOpenedAt: new Date().toISOString(),
  });
}

export function maybeRecordFirstReturnRerecordWithin10Min(): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  const metrics = readMetrics();
  if (!metrics.firstReturnShownAt || metrics.rerecordWithin10MinAt) return;
  const shownMs = Date.parse(metrics.firstReturnShownAt);
  if (!Number.isFinite(shownMs)) return;
  if (Date.now() - shownMs > RERECORD_WINDOW_MS) return;
  writeMetrics({
    ...metrics,
    rerecordWithin10MinAt: new Date().toISOString(),
  });
}
