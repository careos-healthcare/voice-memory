import { BLIND_SPOT_EVENTS, readBlindSpotAnalyticsEvents } from "@/lib/blind-spots/blind-spot-events";
import { readAllBreakthroughCaptures } from "@/lib/blind-spots/breakthrough-capture";
import { readAllDelayedValidations } from "@/lib/blind-spots/delayed-validation";
import { patternTypeFromReviewId } from "@/lib/blind-spots/blind-spot-events";
import { averageWowMomentScore, sumWowMomentScore } from "@/lib/blind-spots/wow-moment-score";
import type { BlindSpotFeedbackRecord, BlindSpotReaction } from "@/types/blind-spot";
import type {
  BlindSpotDiscoveryReport,
  BreakthroughPhraseSummary,
  PatternCategoryRow,
  WowBucketRow,
  WowMomentRow,
} from "@/types/blind-spot-discovery";

const STRONG_REACTIONS: BlindSpotReaction[] = ["surprising", "uncomfortably_accurate"];
const WEAK_REACTIONS: BlindSpotReaction[] = ["obvious", "completely_wrong"];

function normalizePhrase(phrase: string): string {
  return phrase.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 120);
}

function countEvents(name: string): number {
  return readBlindSpotAnalyticsEvents().filter((e) => e.name === name).length;
}

function reflectionCountBucket(count: number): string {
  if (count < 5) return "2–4 reflections";
  if (count < 10) return "5–9 reflections";
  if (count < 20) return "10–19 reflections";
  return "20+ reflections";
}

function archiveAgeBucket(days: number): string {
  if (days < 7) return "Under 1 week";
  if (days < 30) return "1–4 weeks";
  if (days < 90) return "1–3 months";
  return "3+ months";
}

function groupByReviewId(records: BlindSpotFeedbackRecord[]): Map<string, BlindSpotFeedbackRecord[]> {
  const map = new Map<string, BlindSpotFeedbackRecord[]>();
  for (const record of records) {
    const list = map.get(record.reviewId) ?? [];
    list.push(record);
    map.set(record.reviewId, list);
  }
  return map;
}

function enrichRecord(record: BlindSpotFeedbackRecord): BlindSpotFeedbackRecord & {
  patternType: string;
  reflectionCount: number;
  archiveAgeDays: number;
} {
  return {
    ...record,
    patternType:
      "patternType" in record && typeof record.patternType === "string"
        ? record.patternType
        : patternTypeFromReviewId(record.reviewId),
    reflectionCount:
      "reflectionCount" in record && typeof record.reflectionCount === "number"
        ? record.reflectionCount
        : 0,
    archiveAgeDays:
      "archiveAgeDays" in record && typeof record.archiveAgeDays === "number"
        ? record.archiveAgeDays
        : 0,
  };
}

export function buildTopWowMoments(records: BlindSpotFeedbackRecord[]): WowMomentRow[] {
  const byReview = groupByReviewId(records);

  return [...byReview.entries()]
    .map(([reviewId, group]) => {
      const reactions = group.map((r) => r.reaction);
      const last = enrichRecord(group[group.length - 1]!);
      return {
        reviewId,
        headline: last.headline,
        patternType: last.patternType,
        wowMomentScore: sumWowMomentScore(reactions),
        reactionCount: group.length,
      };
    })
    .sort((a, b) => b.wowMomentScore - a.wowMomentScore || b.reactionCount - a.reactionCount)
    .slice(0, 8);
}

export function buildPatternCategoryRows(records: BlindSpotFeedbackRecord[]): PatternCategoryRow[] {
  const byType = new Map<string, BlindSpotFeedbackRecord[]>();

  for (const record of records) {
    const enriched = enrichRecord(record);
    const list = byType.get(enriched.patternType) ?? [];
    list.push(record);
    byType.set(enriched.patternType, list);
  }

  return [...byType.entries()].map(([patternType, group]) => {
    const reactions = group.map((r) => r.reaction);
    return {
      patternType,
      wowMomentScore: sumWowMomentScore(reactions),
      surprisingCount: reactions.filter((r) => r === "surprising").length,
      uncomfortablyAccurateCount: reactions.filter((r) => r === "uncomfortably_accurate").length,
      obviousCount: reactions.filter((r) => r === "obvious").length,
      completelyWrongCount: reactions.filter((r) => r === "completely_wrong").length,
      reactionCount: group.length,
    };
  });
}

function bucketWowRows(
  records: BlindSpotFeedbackRecord[],
  bucketFn: (r: ReturnType<typeof enrichRecord>) => string,
): WowBucketRow[] {
  const buckets = new Map<string, BlindSpotReaction[]>();

  for (const record of records) {
    const enriched = enrichRecord(record);
    const key = bucketFn(enriched);
    const list = buckets.get(key) ?? [];
    list.push(record.reaction);
    buckets.set(key, list);
  }

  return [...buckets.entries()].map(([bucket, reactions]) => ({
    bucket,
    totalReactions: reactions.length,
    averageWowScore: averageWowMomentScore(reactions),
    surprisingCount: reactions.filter((r) => r === "surprising").length,
    uncomfortablyAccurateCount: reactions.filter((r) => r === "uncomfortably_accurate").length,
  }));
}

export function summarizeBreakthroughPhrases(): BreakthroughPhraseSummary[] {
  const captures = readAllBreakthroughCaptures();
  const counts = new Map<string, number>();

  for (const capture of captures) {
    const key = normalizePhrase(capture.phrase);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  return [...counts.entries()]
    .map(([phrase, count]) => ({ phrase, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 12);
}

function buildSurfaceEngagement(
  records: BlindSpotFeedbackRecord[],
  surfaceOpens: BlindSpotDiscoveryReport["surfaceOpens"],
): BlindSpotDiscoveryReport["surfaceEngagement"] {
  const blindSpotReactions = records.length;
  const blindSpotOpens = surfaceOpens.blindSpotOpened;
  const predictionTotal =
    surfaceOpens.predictionReviewOpened + surfaceOpens.predictionAccuracyOpened;

  return {
    blindSpotReactions,
    blindSpotOpens,
    emergingPatternOpens: surfaceOpens.emergingPatternOpened,
    predictionReviewOpens: surfaceOpens.predictionReviewOpened,
    predictionAccuracyOpens: surfaceOpens.predictionAccuracyOpened,
    opensPerReaction:
      blindSpotReactions > 0
        ? Math.round((blindSpotOpens / blindSpotReactions) * 100) / 100
        : 0,
    predictionOpensVsBlindSpotOpens: blindSpotOpens > 0 ? predictionTotal / blindSpotOpens : 0,
    emergingOpensVsBlindSpotOpens:
      blindSpotOpens > 0 ? surfaceOpens.emergingPatternOpened / blindSpotOpens : 0,
  };
}

/** Discover which conditions produce strongest self-recognition reactions. */
export function buildSelfRecognitionAnalysis(
  records: BlindSpotFeedbackRecord[],
): BlindSpotDiscoveryReport {
  const patternRows = buildPatternCategoryRows(records);
  const highest = [...patternRows]
    .sort((a, b) => b.wowMomentScore - a.wowMomentScore)
    .slice(0, 5);
  const lowest = [...patternRows]
    .sort((a, b) => a.wowMomentScore - b.wowMomentScore)
    .slice(0, 5);

  const delayed = readAllDelayedValidations();
  const surfaceOpens = {
    blindSpotOpened: countEvents(BLIND_SPOT_EVENTS.blindSpotOpened),
    emergingPatternOpened: countEvents(BLIND_SPOT_EVENTS.emergingPatternOpened),
    predictionReviewOpened: countEvents(BLIND_SPOT_EVENTS.predictionReviewOpened),
    predictionAccuracyOpened: countEvents(BLIND_SPOT_EVENTS.predictionAccuracyOpened),
  };

  return {
    topWowMoments: buildTopWowMoments(records),
    highestRecognitionPatterns: highest,
    lowestRecognitionPatterns: lowest,
    evidenceStrengthVsWow: bucketWowRows(records, (r) => r.evidenceStrength),
    reflectionCountVsWow: bucketWowRows(records, (r) =>
      reflectionCountBucket(r.reflectionCount),
    ),
    archiveAgeVsWow: bucketWowRows(records, (r) => archiveAgeBucket(r.archiveAgeDays)),
    surfaceOpens,
    surfaceEngagement: buildSurfaceEngagement(records, surfaceOpens),
    breakthroughPhrases: summarizeBreakthroughPhrases(),
    delayedValidation: {
      pending: delayed.filter((d) => !d.response).length,
      responded: delayed.filter((d) => d.response).length,
      changedMind: delayed.filter((d) => d.response === "changed_mind").length,
      stillWrong: delayed.filter((d) => d.response === "still_wrong").length,
      nowAccurate: delayed.filter((d) => d.response === "now_accurate").length,
    },
    generatedAt: new Date().toISOString(),
  };
}

export function countStrongReactions(records: BlindSpotFeedbackRecord[]): number {
  return records.filter((r) => STRONG_REACTIONS.includes(r.reaction)).length;
}

export function countWeakReactions(records: BlindSpotFeedbackRecord[]): number {
  return records.filter((r) => WEAK_REACTIONS.includes(r.reaction)).length;
}
