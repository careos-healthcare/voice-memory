const CACHE_PREFIX = "voicememory_weekly_summary_";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getCachedWeeklySummary(weekEndingKey: string): string | null {
  if (!isBrowser()) return null;
  try {
    return localStorage.getItem(`${CACHE_PREFIX}${weekEndingKey}`);
  } catch {
    return null;
  }
}

export function setCachedWeeklySummary(
  weekEndingKey: string,
  summary: string,
): void {
  if (!isBrowser()) return;
  try {
    localStorage.setItem(`${CACHE_PREFIX}${weekEndingKey}`, summary);
  } catch {
    // Quota or private mode
  }
}

export function clearAllWeeklySummaryCache(): void {
  if (!isBrowser()) return;
  try {
    const keys: string[] = [];
    for (let i = 0; i < localStorage.length; i += 1) {
      const key = localStorage.key(i);
      if (key?.startsWith(CACHE_PREFIX)) keys.push(key);
    }
    for (const key of keys) {
      localStorage.removeItem(key);
    }
  } catch {
    // Best-effort
  }
}
