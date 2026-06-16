import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type { LocalAnalyticsEvent } from "@/lib/local-analytics";
import type { BlindSpotReaction, EvidenceStrengthLabel } from "@/types/blind-spot";
import type { JournalEntry } from "@/types/journal";

export const BLIND_SPOT_EVENTS = {
  blindSpotOpened: "blind_spot_opened",
  blindSpotReaction: "blind_spot_reaction",
  emergingPatternOpened: "emerging_pattern_opened",
  predictionReviewOpened: "prediction_review_opened",
  predictionAccuracyOpened: "prediction_accuracy_opened",
} as const;

export type BlindSpotEventName =
  (typeof BLIND_SPOT_EVENTS)[keyof typeof BLIND_SPOT_EVENTS];

export interface BlindSpotEventMeta {
  reviewId?: string;
  evidenceStrength?: EvidenceStrengthLabel;
  estimatedImpactScore?: number;
  reaction?: BlindSpotReaction;
  reflectionCount?: number;
  archiveAgeDays?: number;
  patternType?: string;
  emergingPatternId?: string;
}

function metaToStrings(meta: BlindSpotEventMeta): Record<string, string> {
  const out: Record<string, string> = {};
  if (meta.reviewId) out.reviewId = meta.reviewId;
  if (meta.evidenceStrength) out.evidenceStrength = meta.evidenceStrength;
  if (meta.estimatedImpactScore !== undefined) {
    out.estimatedImpactScore = String(meta.estimatedImpactScore);
  }
  if (meta.reaction) out.reaction = meta.reaction;
  if (meta.reflectionCount !== undefined) out.reflectionCount = String(meta.reflectionCount);
  if (meta.archiveAgeDays !== undefined) out.archiveAgeDays = String(meta.archiveAgeDays);
  if (meta.patternType) out.patternType = meta.patternType;
  if (meta.emergingPatternId) out.emergingPatternId = meta.emergingPatternId;
  return out;
}

export function patternTypeFromReviewId(reviewId: string): string {
  const parts = reviewId.split(":");
  if (parts.length >= 2 && parts[0] === "blind-spot") return parts[1] ?? "unknown";
  if (parts[0] === "emerging") return parts[1] ?? "emerging";
  return "unknown";
}

/** Span in days from first to latest eligible reflection. */
export function computeArchiveAgeDays(entries: JournalEntry[]): number {
  const eligible = entries.filter((e) => e.reflectionPending !== true);
  if (eligible.length === 0) return 0;
  const keys = eligible
    .map((e) => toDayKey(e.createdAt))
    .sort();
  return Math.max(0, daysBetweenKeys(keys[0]!, keys[keys.length - 1]!));
}

const EVENTS_KEY = "voicememory_local_events";

function analyticsStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

/** Read blind-spot events from local analytics store (browser + Node eval). */
export function readBlindSpotAnalyticsEvents(): LocalAnalyticsEvent[] {
  const store = analyticsStorage();
  let stored: LocalAnalyticsEvent[] = [];
  if (store) {
    try {
      const raw = store.getItem(EVENTS_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as LocalAnalyticsEvent[];
        stored = Array.isArray(parsed) ? parsed : [];
      }
    } catch {
      stored = [];
    }
  }
  if (typeof window !== "undefined") {
    const live = readLocalEvents();
    if (live.length > 0) return live;
  }
  return stored;
}

export function trackBlindSpotEvent(name: BlindSpotEventName, meta: BlindSpotEventMeta = {}): void {
  trackLocalEvent(name, metaToStrings(meta));
}

/** Direct append for Node validation (bypasses browser guard). */
export function appendBlindSpotEventForEval(
  name: BlindSpotEventName,
  meta: BlindSpotEventMeta = {},
  at?: string,
): void {
  const store =
    typeof globalThis.localStorage !== "undefined" ? globalThis.localStorage : null;
  if (!store) return;
  let events: Array<{ name: string; at: string; meta?: Record<string, string> }> = [];
  try {
    const raw = store.getItem(EVENTS_KEY);
    events = raw ? JSON.parse(raw) : [];
    if (!Array.isArray(events)) events = [];
  } catch {
    events = [];
  }
  events.push({
    name,
    at: at ?? new Date().toISOString(),
    meta: metaToStrings(meta),
  });
  store.setItem(EVENTS_KEY, JSON.stringify(events.slice(-500)));
}
