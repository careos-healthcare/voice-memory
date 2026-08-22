const RENDER_WARN_THRESHOLD = 10;
const INVOCATION_WARN_THRESHOLD = 10;

export interface OpenLoopPerformanceSnapshot {
  renders: Record<string, number>;
  invocations: Record<string, number>;
  storageReads: number;
  storageWrites: number;
  unresolvedDetectionRuns: number;
  continuityBuildMs: number;
  deferredTaskMs: number;
  warnings: string[];
  updatedAt: string;
}

const renders = new Map<string, number>();
const invocations = new Map<string, number>();
const warnings: string[] = [];

let storageReads = 0;
let storageWrites = 0;
let unresolvedDetectionRuns = 0;
let continuityBuildMs = 0;
let deferredTaskMs = 0;

function pushWarning(message: string): void {
  if (warnings.includes(message)) return;
  warnings.push(message);
  if (typeof console !== "undefined" && process.env.NODE_ENV !== "production") {
    console.warn(`[open-loop-performance] ${message}`);
  }
}

function bumpInvocation(name: string): void {
  const next = (invocations.get(name) ?? 0) + 1;
  invocations.set(name, next);
  if (next > INVOCATION_WARN_THRESHOLD) {
    pushWarning(`${name} invoked ${next}× (threshold ${INVOCATION_WARN_THRESHOLD})`);
  }
}

export function recordComponentRender(component: string): number {
  const next = (renders.get(component) ?? 0) + 1;
  renders.set(component, next);
  if (next > RENDER_WARN_THRESHOLD) {
    pushWarning(`${component} rendered ${next}× (threshold ${RENDER_WARN_THRESHOLD})`);
  }
  return next;
}

export function recordFunctionInvocation(name: string): void {
  bumpInvocation(name);
}

export function recordUnresolvedDetectionInvocation(): void {
  unresolvedDetectionRuns += 1;
  bumpInvocation("detectUnresolvedThread");
}

export function recordStorageRead(count = 1): void {
  storageReads += count;
  bumpInvocation("localStorage.read");
}

export function recordStorageWrite(count = 1): void {
  storageWrites += count;
  bumpInvocation("localStorage.write");
}

export function recordContinuityBuildDuration(ms: number): void {
  continuityBuildMs += ms;
}

export function recordDeferredTaskDuration(ms: number): void {
  deferredTaskMs += ms;
}

export function transcriptCacheKey(transcript: string): string {
  const text = transcript.trim();
  let hash = 0;
  for (let i = 0; i < text.length; i += 1) {
    hash = (hash * 31 + text.charCodeAt(i)) | 0;
  }
  return `${text.length}:${hash >>> 0}`;
}

export function getOpenLoopPerformanceSnapshot(): OpenLoopPerformanceSnapshot {
  return {
    renders: Object.fromEntries(renders),
    invocations: Object.fromEntries(invocations),
    storageReads,
    storageWrites,
    unresolvedDetectionRuns,
    continuityBuildMs,
    deferredTaskMs,
    warnings: [...warnings],
    updatedAt: new Date().toISOString(),
  };
}

export function resetOpenLoopPerformanceCounters(): void {
  renders.clear();
  invocations.clear();
  warnings.length = 0;
  storageReads = 0;
  storageWrites = 0;
  unresolvedDetectionRuns = 0;
  continuityBuildMs = 0;
  deferredTaskMs = 0;
}

export function getUnresolvedDetectionRunCount(): number {
  return unresolvedDetectionRuns;
}
