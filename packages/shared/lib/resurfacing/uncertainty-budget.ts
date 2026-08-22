import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";

const BUDGET_KEY = "voicememory_resurfacing_uncertainty_budget";
const WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_CAUTIOUS_IN_WINDOW = 3;

interface BudgetRecord {
  cautiousShownAt: string[];
}

function isBrowser(): boolean {
  return typeof localStorage !== "undefined";
}

function read(): BudgetRecord {
  if (!isBrowser()) return { cautiousShownAt: [] };
  try {
    const raw = localStorage.getItem(BUDGET_KEY);
    if (!raw) return { cautiousShownAt: [] };
    const parsed = JSON.parse(raw) as Partial<BudgetRecord>;
    return {
      cautiousShownAt: Array.isArray(parsed.cautiousShownAt)
        ? parsed.cautiousShownAt
        : [],
    };
  } catch {
    return { cautiousShownAt: [] };
  }
}

function write(record: BudgetRecord): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  if (typeof localStorage.setItem !== "function") return;
  localStorage.setItem(BUDGET_KEY, JSON.stringify(record));
}

function prune(times: string[]): string[] {
  const cutoff = Date.now() - WINDOW_MS;
  return times.filter((t) => Date.parse(t) >= cutoff);
}

export function getRecentCautiousCallbackCount(): number {
  return prune(read().cautiousShownAt).length;
}

export function isUncertaintyBudgetExceeded(): boolean {
  return getRecentCautiousCallbackCount() >= MAX_CAUTIOUS_IN_WINDOW;
}

export function recordCautiousCallbackShown(): void {
  const record = read();
  record.cautiousShownAt = prune(record.cautiousShownAt);
  record.cautiousShownAt.push(new Date().toISOString());
  write(record);
}

export function clearUncertaintyBudgetForEval(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(BUDGET_KEY);
}
