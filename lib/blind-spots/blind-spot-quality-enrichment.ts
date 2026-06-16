import { getBlindSpotReaction, readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { readAllBreakthroughCaptures } from "@/lib/blind-spots/breakthrough-capture";
import { computeBlindSpotQualityScore } from "@/lib/blind-spots/blind-spot-quality-score";
import { readAllInsightOutcomeEvents } from "@/lib/insights/insight-outcome-storage";
import { readAllBreakthroughEvents } from "@/lib/breakthrough/breakthrough-events";
import type {
  BlindSpotQualityEnrichedRecord,
  BlindSpotQualityOutcomes,
  BlindSpotQualityRecord,
} from "@/types/blind-spot-quality";

const BEHAVIOR_BREAKTHROUGH_TYPES = new Set([
  "acted_differently",
  "behavior_changed",
  "caught_it_earlier",
  "noticed_pattern",
  "blind_spot_resolved",
]);

function latestReactionByReview(
  records: ReturnType<typeof readAllBlindSpotFeedback>,
): Map<string, string> {
  const map = new Map<string, string>();
  const sorted = [...records].sort((a, b) => a.at.localeCompare(b.at));
  for (const row of sorted) {
    map.set(row.reviewId, row.reaction);
  }
  return map;
}

function buildBreakthroughByReview(): Set<string> {
  const ids = new Set<string>();
  for (const capture of readAllBreakthroughCaptures()) {
    ids.add(capture.reviewId);
  }
  for (const event of readAllBreakthroughEvents()) {
    if (event.answer !== "yes") continue;
    const reviewId = event.relatedBlindSpotId ?? event.attribution?.relatedBlindSpotId;
    if (!reviewId) continue;
    if (BEHAVIOR_BREAKTHROUGH_TYPES.has(event.type)) {
      ids.add(reviewId);
    }
  }
  return ids;
}

function buildOutcomesByReview(): Map<string, BlindSpotQualityOutcomes> {
  const map = new Map<string, BlindSpotQualityOutcomes>();
  const reactions = latestReactionByReview(readAllBlindSpotFeedback());
  const breakthroughReviews = buildBreakthroughByReview();

  for (const event of readAllInsightOutcomeEvents()) {
    if (event.insightType !== "blind_spot" || !event.outcome) continue;
    const existing = map.get(event.insightId) ?? emptyOutcomes();
    if (event.outcome === "acted_differently") existing.actedDifferently = true;
    if (event.outcome === "problem_improved") existing.problemImproved = true;
    map.set(event.insightId, existing);
  }

  for (const reviewId of reactions.keys()) {
    const reaction = reactions.get(reviewId);
    const existing = map.get(reviewId) ?? emptyOutcomes();
    if (reaction === "surprising") existing.surprising = true;
    if (reaction === "uncomfortably_accurate") existing.uncomfortablyAccurate = true;
    map.set(reviewId, existing);
  }

  for (const reviewId of breakthroughReviews) {
    const existing = map.get(reviewId) ?? emptyOutcomes();
    existing.breakthrough = true;
    map.set(reviewId, existing);
  }

  return map;
}

function emptyOutcomes(): BlindSpotQualityOutcomes {
  return {
    surprising: false,
    uncomfortablyAccurate: false,
    breakthrough: false,
    actedDifferently: false,
    problemImproved: false,
  };
}

export function resolveBlindSpotQualityOutcomes(
  record: BlindSpotQualityRecord,
  outcomesByReview?: Map<string, BlindSpotQualityOutcomes>,
): BlindSpotQualityOutcomes {
  const map = outcomesByReview ?? buildOutcomesByReview();
  const fromMap = map.get(record.reviewId);
  if (fromMap) return { ...fromMap };

  const reaction = getBlindSpotReaction(record.reviewId);
  const outcomes = emptyOutcomes();
  if (reaction === "surprising") outcomes.surprising = true;
  if (reaction === "uncomfortably_accurate") outcomes.uncomfortablyAccurate = true;
  return outcomes;
}

export function enrichBlindSpotQualityRecord(
  record: BlindSpotQualityRecord,
  outcomesByReview?: Map<string, BlindSpotQualityOutcomes>,
): BlindSpotQualityEnrichedRecord {
  const outcomes = resolveBlindSpotQualityOutcomes(record, outcomesByReview);
  return {
    ...record,
    outcomes,
    blindSpotQualityScore: computeBlindSpotQualityScore(outcomes),
  };
}

export function enrichAllBlindSpotQualityRecords(
  records: BlindSpotQualityRecord[],
): BlindSpotQualityEnrichedRecord[] {
  const outcomesByReview = buildOutcomesByReview();
  return records.map((record) => enrichBlindSpotQualityRecord(record, outcomesByReview));
}
