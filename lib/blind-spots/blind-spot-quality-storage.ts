import { patternTypeFromReviewId } from "@/lib/blind-spots/blind-spot-events";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type { BlindSpotReviewSnapshot } from "@/types/blind-spot-review-snapshot";
import type { BlindSpotQualityRecord } from "@/types/blind-spot-quality";

export const BLIND_SPOT_QUALITY_RECORDS_KEY = "voicememory_blind_spot_quality_records";

const MAX_RECORDS = 200;
const LONG_SPAN_DAYS = 30;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

export function blindSpotIdFromReviewId(reviewId: string): string {
  const parts = reviewId.split(":");
  if (parts[0] === "blind-spot" && parts.length >= 3) {
    return `${parts[1]}:${parts.slice(2).join(":")}`;
  }
  return patternTypeFromReviewId(reviewId);
}

function normalize(raw: unknown): BlindSpotQualityRecord | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.reviewId !== "string" || typeof row.headline !== "string") return null;
  if (typeof row.generatedAt !== "string") return null;

  const evidenceStrength = row.evidenceStrength;
  if (
    evidenceStrength !== "low" &&
    evidenceStrength !== "medium" &&
    evidenceStrength !== "high" &&
    evidenceStrength !== "very_high"
  ) {
    return null;
  }

  return {
    reviewId: row.reviewId,
    blindSpotId:
      typeof row.blindSpotId === "string"
        ? row.blindSpotId
        : blindSpotIdFromReviewId(row.reviewId),
    headline: row.headline,
    scorecardScore: typeof row.scorecardScore === "number" ? row.scorecardScore : 0,
    evidenceStrength,
    contradictionPresent: Boolean(row.contradictionPresent),
    costEvidencePresent: Boolean(row.costEvidencePresent),
    crossLifeAreaPresent: Boolean(row.crossLifeAreaPresent),
    failedPredictionPresent: Boolean(row.failedPredictionPresent),
    longSpanPresent: Boolean(row.longSpanPresent),
    rootBeliefPresent: Boolean(row.rootBeliefPresent),
    generatedAt: row.generatedAt,
  };
}

export function readAllBlindSpotQualityRecords(): BlindSpotQualityRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(BLIND_SPOT_QUALITY_RECORDS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalize)
      .filter((r): r is BlindSpotQualityRecord => Boolean(r))
      .sort((a, b) => b.generatedAt.localeCompare(a.generatedAt));
  } catch {
    return [];
  }
}

function writeAll(records: BlindSpotQualityRecord[]): void {
  getStorage()?.setItem(
    BLIND_SPOT_QUALITY_RECORDS_KEY,
    JSON.stringify(records.slice(0, MAX_RECORDS)),
  );
}

export function qualityRecordFromReview(review: BlindSpotReviewResult): BlindSpotQualityRecord {
  const facts = review.evidenceStrengthFacts;
  return {
    reviewId: review.reviewId,
    blindSpotId: blindSpotIdFromReviewId(review.reviewId),
    headline: review.headline,
    scorecardScore: review.scorecard?.score ?? 0,
    evidenceStrength: review.evidenceStrength,
    contradictionPresent: facts.contradictionPresent || Boolean(review.contradictionNote),
    costEvidencePresent: facts.costEvidenceCount > 0 || review.costEvidenceLines.length > 0,
    crossLifeAreaPresent: facts.lifeAreaCount >= 2 || review.linkedAreas.length >= 2,
    failedPredictionPresent:
      facts.failedPredictionCount > 0 || Boolean(review.predictionEvidenceNote),
    longSpanPresent: facts.spanDays >= LONG_SPAN_DAYS,
    rootBeliefPresent: Boolean(review.rootBeliefHypothesis?.trim()),
    generatedAt: review.generatedAt,
  };
}

export function qualityRecordFromSnapshot(snapshot: BlindSpotReviewSnapshot): BlindSpotQualityRecord {
  return {
    reviewId: snapshot.reviewId,
    blindSpotId: blindSpotIdFromReviewId(snapshot.reviewId),
    headline: snapshot.headline,
    scorecardScore: snapshot.scorecardScore,
    evidenceStrength: snapshot.evidenceStrength,
    contradictionPresent: snapshot.contradictionPresent,
    costEvidencePresent: snapshot.costEvidenceCount > 0,
    crossLifeAreaPresent: snapshot.lifeAreaCount >= 2,
    failedPredictionPresent: snapshot.failedPredictionCount > 0,
    longSpanPresent: snapshot.spanDays >= LONG_SPAN_DAYS,
    rootBeliefPresent: Boolean(snapshot.rootBeliefHypothesis?.trim()),
    generatedAt: snapshot.savedAt,
  };
}

/** Persist one quality row per generated review (deduped by reviewId + generatedAt). */
export function persistBlindSpotQualityRecord(
  input: BlindSpotQualityRecord,
): BlindSpotQualityRecord {
  const records = readAllBlindSpotQualityRecords();
  const duplicate = records.find(
    (r) => r.reviewId === input.reviewId && r.generatedAt === input.generatedAt,
  );
  if (duplicate) return duplicate;

  records.unshift(input);
  writeAll(records);
  return input;
}

export function persistBlindSpotQualityFromReview(review: BlindSpotReviewResult): BlindSpotQualityRecord {
  return persistBlindSpotQualityRecord(qualityRecordFromReview(review));
}

export function clearBlindSpotQualityRecordsForEval(): void {
  getStorage()?.removeItem(BLIND_SPOT_QUALITY_RECORDS_KEY);
}

/** Test helper — seed without going through review builder. */
export function appendBlindSpotQualityRecordForEval(
  input: Partial<BlindSpotQualityRecord> & Pick<BlindSpotQualityRecord, "reviewId" | "headline">,
): BlindSpotQualityRecord {
  const record: BlindSpotQualityRecord = {
    reviewId: input.reviewId,
    blindSpotId: input.blindSpotId ?? blindSpotIdFromReviewId(input.reviewId),
    headline: input.headline,
    scorecardScore: input.scorecardScore ?? 50,
    evidenceStrength: input.evidenceStrength ?? "medium",
    contradictionPresent: input.contradictionPresent ?? false,
    costEvidencePresent: input.costEvidencePresent ?? false,
    crossLifeAreaPresent: input.crossLifeAreaPresent ?? false,
    failedPredictionPresent: input.failedPredictionPresent ?? false,
    longSpanPresent: input.longSpanPresent ?? false,
    rootBeliefPresent: input.rootBeliefPresent ?? false,
    generatedAt: input.generatedAt ?? new Date().toISOString(),
  };
  return persistBlindSpotQualityRecord(record);
}
