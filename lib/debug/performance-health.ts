import { getAnalyticsQueueSize, readLocalEvents } from "@/lib/local-analytics";
import { getPerfSnapshot } from "@/lib/performance/perf-instrumentation";
import { isLightweightMode } from "@/lib/performance/lightweight-mode";
import { getMemoryEligibleEntries, getMemoryEligibleEntriesVersion } from "@/lib/storage";

export interface PerformanceHealthReport {
  generatedAt: string;
  lightweightMode: boolean;
  analyticsQueueSize: number;
  analyticsEventCount: number;
  localStorageBytesEstimate: number;
  entriesCount: number;
  entriesCacheVersion: number;
  renderCounts: Array<{ surface: string; count: number }>;
  slowestModules: Array<{ label: string; durationMs: number }>;
  largestLocalKeys: Array<{ key: string; bytes: number }>;
}

function estimateLocalStorageBytes(): number {
  if (typeof window === "undefined") return 0;
  let total = 0;
  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (!key) continue;
    const value = localStorage.getItem(key) ?? "";
    total += key.length + value.length;
  }
  return total * 2;
}

function largestLocalStorageKeys(limit = 8): Array<{ key: string; bytes: number }> {
  if (typeof window === "undefined") return [];
  const rows: Array<{ key: string; bytes: number }> = [];
  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (!key) continue;
    const value = localStorage.getItem(key) ?? "";
    rows.push({ key, bytes: (key.length + value.length) * 2 });
  }
  return rows.sort((a, b) => b.bytes - a.bytes).slice(0, limit);
}

export function buildPerformanceHealthReport(): PerformanceHealthReport {
  const perf = getPerfSnapshot();
  const entries = getMemoryEligibleEntries();

  return {
    generatedAt: new Date().toISOString(),
    lightweightMode: isLightweightMode(),
    analyticsQueueSize: getAnalyticsQueueSize(),
    analyticsEventCount: readLocalEvents().length,
    localStorageBytesEstimate: estimateLocalStorageBytes(),
    entriesCount: entries.length,
    entriesCacheVersion: getMemoryEligibleEntriesVersion(),
    renderCounts: perf.renderCounts,
    slowestModules: perf.slowest.map((row) => ({
      label: row.label,
      durationMs: row.durationMs,
    })),
    largestLocalKeys: largestLocalStorageKeys(),
  };
}
