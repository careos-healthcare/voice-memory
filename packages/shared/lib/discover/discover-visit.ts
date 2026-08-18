import {
  buildDiscoverEvidenceContext,
  DISCOVER_BASELINE_VERSION,
  migrateLegacyBaselineTheory,
  theoryToEvidenceBaseline,
} from "@/lib/discover/theory-evidence-snapshot";
import type { DiscoverVisitBaseline, Theory } from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

const BASELINE_KEY = "voicememory_discover_visit_baseline";
const LAST_VISIT_KEY = "voicememory_discover_last_visit_at";

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function normalizeBaseline(raw: unknown): DiscoverVisitBaseline | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (!Array.isArray(row.theories)) return null;

  const theories = row.theories
    .map((t) => migrateLegacyBaselineTheory(t as Record<string, unknown>))
    .filter((t): t is NonNullable<typeof t> => Boolean(t));

  return {
    savedAt: typeof row.savedAt === "string" ? row.savedAt : new Date().toISOString(),
    version: typeof row.version === "number" ? row.version : 1,
    theories,
  };
}

export function readDiscoverBaseline(): DiscoverVisitBaseline | null {
  const store = getStorage();
  if (!store) return null;
  try {
    const raw = store.getItem(BASELINE_KEY);
    if (!raw) return null;
    return normalizeBaseline(JSON.parse(raw));
  } catch {
    return null;
  }
}

export function readDiscoverLastVisitAt(): string | null {
  return getStorage()?.getItem(LAST_VISIT_KEY) ?? null;
}

export function saveDiscoverVisitBaseline(theories: Theory[], entries: JournalEntry[]): void {
  const store = getStorage();
  if (!store) return;
  const now = new Date().toISOString();
  const context = buildDiscoverEvidenceContext(entries);
  const baseline: DiscoverVisitBaseline = {
    savedAt: now,
    version: DISCOVER_BASELINE_VERSION,
    theories: theories.map((t) => theoryToEvidenceBaseline(t, entries, context)),
  };
  store.setItem(BASELINE_KEY, JSON.stringify(baseline));
  store.setItem(LAST_VISIT_KEY, now);
}

/** Back-compat: save theories only when entries unavailable. */
export function saveDiscoverVisitBaselineTheoriesOnly(theories: Theory[]): void {
  const now = new Date().toISOString();
  const baseline: DiscoverVisitBaseline = {
    savedAt: now,
    version: DISCOVER_BASELINE_VERSION,
    theories: theories.map((t) => ({
      id: t.id,
      confidence: t.confidence,
      status: t.status,
      statement: t.statement,
      source: t.source,
      supportingEntryIds: t.supportingEvidence.map((q) => q.entryId),
      contradictingEntryIds: t.contradictingEvidence.map((q) => q.entryId),
      lifeAreas: [],
      costEvidenceLines: [],
    })),
  };
  getStorage()?.setItem(BASELINE_KEY, JSON.stringify(baseline));
  getStorage()?.setItem(LAST_VISIT_KEY, now);
}

export function clearDiscoverVisitForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(BASELINE_KEY);
  store.removeItem(LAST_VISIT_KEY);
}
