import {
  BLIND_SPOT_EVENTS,
  computeArchiveAgeDays,
  patternTypeFromReviewId,
  trackBlindSpotEvent,
} from "@/lib/blind-spots/blind-spot-events";
import { scheduleDelayedValidation } from "@/lib/blind-spots/delayed-validation";
import type {
  BlindSpotFeedbackRecord,
  BlindSpotReaction,
  EvidenceStrengthLabel,
} from "@/types/blind-spot";
import type { JournalEntry } from "@/types/journal";

const FEEDBACK_KEY = "voicememory_blind_spot_feedback";
const MAX_RECORDS = 500;

function newFeedbackId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `bs-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

const VALID_REACTIONS = new Set<BlindSpotReaction>([
  "obvious",
  "interesting",
  "surprising",
  "uncomfortably_accurate",
  "completely_wrong",
]);

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function getStorage(): Storage | null {
  if (isBrowser()) return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function normalizeRecord(raw: unknown): BlindSpotFeedbackRecord | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.reaction !== "string" || !VALID_REACTIONS.has(row.reaction as BlindSpotReaction)) {
    return null;
  }
  if (typeof row.reviewId !== "string" || typeof row.headline !== "string") return null;
  return {
    id: typeof row.id === "string" ? row.id : newFeedbackId(),
    reviewId: row.reviewId,
    reaction: row.reaction as BlindSpotReaction,
    comment: typeof row.comment === "string" ? row.comment.trim() || undefined : undefined,
    at: typeof row.at === "string" ? row.at : new Date().toISOString(),
    headline: row.headline,
    evidenceStrength: (row.evidenceStrength as EvidenceStrengthLabel) ?? "medium",
    estimatedImpactScore:
      typeof row.estimatedImpactScore === "number" ? row.estimatedImpactScore : 0,
    reflectionCount: typeof row.reflectionCount === "number" ? row.reflectionCount : 0,
    archiveAgeDays: typeof row.archiveAgeDays === "number" ? row.archiveAgeDays : 0,
    patternType:
      typeof row.patternType === "string"
        ? row.patternType
        : patternTypeFromReviewId(row.reviewId as string),
  };
}

function readAll(): BlindSpotFeedbackRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(FEEDBACK_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed.map(normalizeRecord).filter((r): r is BlindSpotFeedbackRecord => Boolean(r));
  } catch {
    return [];
  }
}

function writeAll(records: BlindSpotFeedbackRecord[]): void {
  const store = getStorage();
  if (!store) return;
  store.setItem(FEEDBACK_KEY, JSON.stringify(records.slice(-MAX_RECORDS)));
}

export function getBlindSpotReaction(reviewId: string): BlindSpotReaction | undefined {
  const matches = readAll()
    .filter((r) => r.reviewId === reviewId)
    .sort((a, b) => b.at.localeCompare(a.at));
  return matches[0]?.reaction;
}

export function saveBlindSpotReaction(input: {
  reviewId: string;
  reaction: BlindSpotReaction;
  comment?: string;
  headline: string;
  evidenceStrength: EvidenceStrengthLabel;
  estimatedImpactScore: number;
  reflectionCount: number;
  archiveAgeDays: number;
  entries?: JournalEntry[];
}): BlindSpotFeedbackRecord {
  const archiveAgeDays =
    input.archiveAgeDays > 0
      ? input.archiveAgeDays
      : input.entries
        ? computeArchiveAgeDays(input.entries)
        : 0;

  const record: BlindSpotFeedbackRecord = {
    id: newFeedbackId(),
    reviewId: input.reviewId,
    reaction: input.reaction,
    comment: input.comment?.trim() || undefined,
    at: new Date().toISOString(),
    headline: input.headline,
    evidenceStrength: input.evidenceStrength,
    estimatedImpactScore: input.estimatedImpactScore,
    reflectionCount: input.reflectionCount,
    archiveAgeDays,
    patternType: patternTypeFromReviewId(input.reviewId),
  };

  const records = readAll();
  records.push(record);
  writeAll(records);

  void import("@/lib/product/activation-metrics").then((mod) => {
    mod.observeStrongReactionFromBlindSpot(record.reaction);
  });

  trackBlindSpotEvent(BLIND_SPOT_EVENTS.blindSpotReaction, {
    reviewId: record.reviewId,
    evidenceStrength: record.evidenceStrength,
    estimatedImpactScore: record.estimatedImpactScore,
    reaction: record.reaction,
    reflectionCount: record.reflectionCount,
    archiveAgeDays: record.archiveAgeDays,
    patternType: record.patternType,
  });

  if (record.reaction === "obvious" || record.reaction === "completely_wrong") {
    scheduleDelayedValidation({
      feedbackId: record.id,
      reviewId: record.reviewId,
      headline: record.headline,
      reaction: record.reaction,
      reactedAt: record.at,
    });
  }

  return record;
}

export function readAllBlindSpotFeedback(): BlindSpotFeedbackRecord[] {
  return readAll();
}

export function clearBlindSpotFeedback(): void {
  getStorage()?.removeItem(FEEDBACK_KEY);
}

/** Test-only: clear and allow Node localStorage mock. */
export function clearBlindSpotFeedbackForEval(): void {
  clearBlindSpotFeedback();
}
