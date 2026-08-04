import "server-only";

import type {
  ArchiveDeepDiveNarrative,
  ArchiveHistorianReport,
  ArchiveMilestoneReview,
  ArchiveMonthlyReview,
} from "@/types/archive-synthesis";
import { synthesisCacheKey } from "@/lib/archive-synthesis/archive-synthesis-hash";

const globalCache = globalThis as typeof globalThis & {
  __vmArchiveSynthesisCache?: Map<string, ArchiveMonthlyReview>;
  __vmArchiveMilestoneCache?: Map<string, ArchiveMilestoneReview>;
  __vmArchiveDeepDiveCache?: Map<string, ArchiveDeepDiveNarrative>;
  __vmArchiveHistorianCache?: Map<string, ArchiveHistorianReport>;
  __vmArchiveSynthesisStats?: { hits: number; misses: number };
};

function stats(): { hits: number; misses: number } {
  if (!globalCache.__vmArchiveSynthesisStats) {
    globalCache.__vmArchiveSynthesisStats = { hits: 0, misses: 0 };
  }
  return globalCache.__vmArchiveSynthesisStats;
}

export function recordCacheHit(): void {
  stats().hits += 1;
}

export function recordCacheMiss(): void {
  stats().misses += 1;
}

export function getSynthesisCacheStats(): {
  hits: number;
  misses: number;
  hitRate: number;
} {
  const { hits, misses } = stats();
  const total = hits + misses;
  return {
    hits,
    misses,
    hitRate: total === 0 ? 0 : hits / total,
  };
}

function mapFor<T>(): Map<string, T> {
  return new Map();
}

function monthlyMap(): Map<string, ArchiveMonthlyReview> {
  if (!globalCache.__vmArchiveSynthesisCache) {
    globalCache.__vmArchiveSynthesisCache = mapFor();
  }
  return globalCache.__vmArchiveSynthesisCache;
}

function milestoneMap(): Map<string, ArchiveMilestoneReview> {
  if (!globalCache.__vmArchiveMilestoneCache) {
    globalCache.__vmArchiveMilestoneCache = mapFor();
  }
  return globalCache.__vmArchiveMilestoneCache;
}

function deepDiveMap(): Map<string, ArchiveDeepDiveNarrative> {
  if (!globalCache.__vmArchiveDeepDiveCache) {
    globalCache.__vmArchiveDeepDiveCache = mapFor();
  }
  return globalCache.__vmArchiveDeepDiveCache;
}

function historianMap(): Map<string, ArchiveHistorianReport> {
  if (!globalCache.__vmArchiveHistorianCache) {
    globalCache.__vmArchiveHistorianCache = mapFor();
  }
  return globalCache.__vmArchiveHistorianCache;
}

const MAX_ENTRIES = 500;

function trimMap<T>(map: Map<string, T>, key: string): void {
  if (map.size >= MAX_ENTRIES && !map.has(key)) {
    const first = map.keys().next().value;
    if (first) map.delete(first);
  }
}

export function getCachedArchiveSynthesis(
  subject: string,
  monthKey: string,
  archiveHash: string,
): ArchiveMonthlyReview | null {
  void synthesisCacheKey(subject, monthKey, archiveHash);
  return null;
}

export function setCachedArchiveSynthesis(
  subject: string,
  review: ArchiveMonthlyReview,
): void {
  void subject;
  void review;
}

export function milestoneCacheKey(
  subject: string,
  threshold: number,
): string {
  return `${subject}:milestone:${threshold}`;
}

export function getCachedMilestoneReview(
  subject: string,
  threshold: number,
): ArchiveMilestoneReview | null {
  void milestoneCacheKey(subject, threshold);
  return null;
}

export function setCachedMilestoneReview(
  subject: string,
  review: ArchiveMilestoneReview,
): void {
  void subject;
  void review;
}

export function deepDiveCacheKey(
  subject: string,
  archiveHash: string,
): string {
  return `${subject}:deep_dive:${archiveHash}`;
}

export function getCachedDeepDiveNarrative(
  subject: string,
  archiveHash: string,
): ArchiveDeepDiveNarrative | null {
  void deepDiveCacheKey(subject, archiveHash);
  return null;
}

export function setCachedDeepDiveNarrative(
  subject: string,
  review: ArchiveDeepDiveNarrative,
): void {
  void subject;
  void review;
}

export function historianCacheKey(
  subject: string,
  monthKey: string,
  archiveHash: string,
): string {
  return `${subject}:historian:${monthKey}:${archiveHash}`;
}

export function getCachedHistorianReport(
  subject: string,
  monthKey: string,
  archiveHash: string,
): ArchiveHistorianReport | null {
  void historianCacheKey(subject, monthKey, archiveHash);
  return null;
}

export function setCachedHistorianReport(
  subject: string,
  review: ArchiveHistorianReport,
): void {
  void subject;
  void review;
}
