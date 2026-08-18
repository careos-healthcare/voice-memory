import { shouldRunDebugAggregation } from "@/lib/performance/debug-isolation";

export interface PerfTimingSample {
  label: string;
  durationMs: number;
  at: string;
}

const timings: PerfTimingSample[] = [];
const renderCounts = new Map<string, number>();
const MAX_TIMINGS = 40;

let deferResurfacing = false;

export function setDeferResurfacingCompute(enabled: boolean): void {
  deferResurfacing = enabled;
}

export function shouldDeferResurfacingCompute(): boolean {
  return deferResurfacing;
}

export function recordPerfTiming(label: string, durationMs: number): void {
  if (!shouldRunDebugAggregation() && process.env.NODE_ENV === "production") return;
  timings.push({
    label,
    durationMs: Math.round(durationMs * 10) / 10,
    at: new Date().toISOString(),
  });
  if (timings.length > MAX_TIMINGS) {
    timings.splice(0, timings.length - MAX_TIMINGS);
  }
}

export function measurePerf<T>(label: string, fn: () => T): T {
  const started = performance.now();
  const result = fn();
  recordPerfTiming(label, performance.now() - started);
  return result;
}

export async function measurePerfAsync<T>(label: string, fn: () => Promise<T>): Promise<T> {
  const started = performance.now();
  const result = await fn();
  recordPerfTiming(label, performance.now() - started);
  return result;
}

export function bumpRenderCount(surface: string): void {
  renderCounts.set(surface, (renderCounts.get(surface) ?? 0) + 1);
}

export function getPerfSnapshot(): {
  renderCounts: Array<{ surface: string; count: number }>;
  timings: PerfTimingSample[];
  slowest: PerfTimingSample[];
} {
  const sorted = [...timings].sort((a, b) => b.durationMs - a.durationMs);
  return {
    renderCounts: [...renderCounts.entries()]
      .map(([surface, count]) => ({ surface, count }))
      .sort((a, b) => b.count - a.count),
    timings: [...timings],
    slowest: sorted.slice(0, 12),
  };
}

export function resetPerfSnapshot(): void {
  timings.length = 0;
  renderCounts.clear();
}
