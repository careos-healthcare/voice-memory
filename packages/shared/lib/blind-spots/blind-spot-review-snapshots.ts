import { persistBlindSpotQualityFromReview } from "@/lib/blind-spots/blind-spot-quality-storage";
import { buildInsightScorecardFromBlindSpotReview } from "@/lib/insights/insight-scorecard";
import { computeEvidenceStrength } from "@/lib/blind-spots/blind-spot-ranking";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type { BlindSpotReviewSnapshot } from "@/types/blind-spot-review-snapshot";

export const BLIND_SPOT_REVIEW_SNAPSHOTS_KEY = "voicememory_blind_spot_review_snapshots";

const MAX_SNAPSHOTS = 30;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `bsrs-${Date.now()}`;
}

function normalize(raw: unknown): BlindSpotReviewSnapshot | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.reviewId !== "string" || typeof row.headline !== "string") return null;
  if (typeof row.savedAt !== "string") return null;
  return {
    snapshotId: typeof row.snapshotId === "string" ? row.snapshotId : newId(),
    reviewId: row.reviewId,
    savedAt: row.savedAt,
    headline: row.headline,
    rootBeliefHypothesis:
      typeof row.rootBeliefHypothesis === "string" ? row.rootBeliefHypothesis : undefined,
    evidenceStrength: row.evidenceStrength as BlindSpotReviewSnapshot["evidenceStrength"],
    evidenceStrengthScore:
      typeof row.evidenceStrengthScore === "number" ? row.evidenceStrengthScore : 0,
    lifeAreas: Array.isArray(row.lifeAreas)
      ? row.lifeAreas.filter((a): a is string => typeof a === "string")
      : [],
    lifeAreaCount: typeof row.lifeAreaCount === "number" ? row.lifeAreaCount : 0,
    spanDays: typeof row.spanDays === "number" ? row.spanDays : 0,
    contradictionPresent: Boolean(row.contradictionPresent),
    costEvidenceCount: typeof row.costEvidenceCount === "number" ? row.costEvidenceCount : 0,
    failedPredictionCount:
      typeof row.failedPredictionCount === "number" ? row.failedPredictionCount : 0,
    entryIds: Array.isArray(row.entryIds)
      ? row.entryIds.filter((id): id is string => typeof id === "string")
      : [],
    matchingReflectionCount:
      typeof row.matchingReflectionCount === "number"
        ? row.matchingReflectionCount
        : Array.isArray(row.entryIds)
          ? row.entryIds.length
          : 0,
    archiveReflectionCount:
      typeof row.archiveReflectionCount === "number"
        ? row.archiveReflectionCount
        : 0,
    archiveEntryIds: Array.isArray(row.archiveEntryIds)
      ? row.archiveEntryIds.filter((id): id is string => typeof id === "string").sort()
      : [],
    scorecardScore: typeof row.scorecardScore === "number" ? row.scorecardScore : 0,
    patternType: typeof row.patternType === "string" ? row.patternType : "",
  };
}

export function readAllBlindSpotReviewSnapshots(): BlindSpotReviewSnapshot[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(BLIND_SPOT_REVIEW_SNAPSHOTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalize)
      .filter((s): s is BlindSpotReviewSnapshot => Boolean(s))
      .sort((a, b) => b.savedAt.localeCompare(a.savedAt));
  } catch {
    return [];
  }
}

export function readLatestBlindSpotReviewSnapshot(): BlindSpotReviewSnapshot | null {
  return readAllBlindSpotReviewSnapshots()[0] ?? null;
}

export function snapshotFromReview(review: BlindSpotReviewResult): BlindSpotReviewSnapshot {
  const facts = review.evidenceStrengthFacts;
  const { score } = computeEvidenceStrength({
    matchingReflections: facts.reflectionCount,
    spanDays: facts.spanDays,
    lifeAreaCount: facts.lifeAreaCount,
    signalBonus: 0,
  });
  const scorecard = review.scorecard ?? buildInsightScorecardFromBlindSpotReview(review);

  return {
    snapshotId: newId(),
    reviewId: review.reviewId,
    savedAt: new Date().toISOString(),
    headline: review.headline,
    rootBeliefHypothesis: review.rootBeliefHypothesis,
    evidenceStrength: review.evidenceStrength,
    evidenceStrengthScore: score,
    lifeAreas: [...review.linkedAreas],
    lifeAreaCount: facts.lifeAreaCount,
    spanDays: facts.spanDays,
    contradictionPresent: facts.contradictionPresent,
    costEvidenceCount: facts.costEvidenceCount,
    failedPredictionCount: facts.failedPredictionCount,
    entryIds: review.evidenceQuotes.map((q) => q.entryId),
    matchingReflectionCount: facts.reflectionCount,
    archiveReflectionCount: review.reflectionCount,
    archiveEntryIds: [...review.archiveEntryIds],
    scorecardScore: scorecard.score,
    patternType: review.reviewId.split(":")[1] ?? "",
  };
}

/** Append snapshot when the surfaced review or its evidence set changes. */
export function persistBlindSpotReviewSnapshot(review: BlindSpotReviewResult): boolean {
  const store = getStorage();
  if (!store) return false;

  const next = snapshotFromReview(review);
  const prior = readLatestBlindSpotReviewSnapshot();
  if (
    prior &&
    prior.reviewId === next.reviewId &&
    prior.headline === next.headline &&
    sameEntrySet(prior.entryIds, next.entryIds) &&
    prior.rootBeliefHypothesis === next.rootBeliefHypothesis &&
    prior.contradictionPresent === next.contradictionPresent &&
    prior.costEvidenceCount === next.costEvidenceCount &&
    sameEntrySet(prior.archiveEntryIds ?? [], next.archiveEntryIds)
  ) {
    return false;
  }

  const all = readAllBlindSpotReviewSnapshots();
  all.unshift(next);
  store.setItem(
    BLIND_SPOT_REVIEW_SNAPSHOTS_KEY,
    JSON.stringify(all.slice(0, MAX_SNAPSHOTS)),
  );
  persistBlindSpotQualityFromReview(review);
  return true;
}

function sameEntrySet(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false;
  const setA = new Set(a);
  return b.every((id) => setA.has(id));
}

export function clearBlindSpotReviewSnapshotsForEval(): void {
  getStorage()?.removeItem(BLIND_SPOT_REVIEW_SNAPSHOTS_KEY);
}
