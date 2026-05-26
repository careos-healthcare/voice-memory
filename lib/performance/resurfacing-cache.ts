import { measurePerf } from "@/lib/performance/perf-instrumentation";
import {
  flushPresentationSideEffects,
  withoutPresentationSideEffects,
} from "@/lib/refinement/presentation-side-effects";
import { buildQuietEntryPresentation } from "@/lib/refinement/quiet-presentation";
import { buildRevisitExperience } from "@/lib/refinement/revisit-experience";
import { runPresentationBuild } from "@/lib/tracking/presentation-guard";
import type { JournalEntry } from "@/types/journal";
import type { QuietEntryPresentation } from "@/lib/refinement/quiet-presentation";
import type { RevisitExperiencePresentation } from "@/lib/refinement/revisit-experience";

const MAX_CACHE = 24;

const presentationCache = new Map<string, QuietEntryPresentation>();
const revisitCache = new Map<string, RevisitExperiencePresentation>();

function limitsKey(limits: Record<string, number>): string {
  return Object.keys(limits)
    .sort()
    .map((key) => `${key}:${limits[key]}`)
    .join("|");
}

function cacheGet<T>(map: Map<string, T>, key: string): T | undefined {
  return map.get(key);
}

function cacheSet<T>(map: Map<string, T>, key: string, value: T): void {
  if (map.size >= MAX_CACHE) {
    const first = map.keys().next().value;
    if (first) map.delete(first);
  }
  map.set(key, value);
}

export function getCachedQuietEntryPresentation(
  entries: JournalEntry[],
  entryId: string,
  limits: {
    changeMoments: number;
    familiarity: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
  entriesVersion: number,
): QuietEntryPresentation {
  const key = `p:${entriesVersion}:${entryId}:${limitsKey(limits)}`;
  const hit = cacheGet(presentationCache, key);
  if (hit) return hit;
  const built = measurePerf("quiet_entry_presentation", () =>
    runPresentationBuild(() => buildQuietEntryPresentation(entries, entryId, limits)),
  );
  flushPresentationSideEffects(built.sideEffects);
  const value = withoutPresentationSideEffects(built);
  cacheSet(presentationCache, key, value);
  return value;
}

export function getCachedRevisitExperience(
  entries: JournalEntry[],
  entryId: string,
  limits: {
    changeMoments: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
  entriesVersion: number,
): RevisitExperiencePresentation {
  const key = `r:${entriesVersion}:${entryId}:${limitsKey(limits)}`;
  const hit = cacheGet(revisitCache, key);
  if (hit) return hit;
  const built = measurePerf("revisit_experience", () =>
    runPresentationBuild(() => buildRevisitExperience(entries, entryId, limits)),
  );
  flushPresentationSideEffects(built.sideEffects);
  const value = withoutPresentationSideEffects(built);
  cacheSet(revisitCache, key, value);
  return value;
}

export function clearResurfacingCaches(): void {
  presentationCache.clear();
  revisitCache.clear();
}
