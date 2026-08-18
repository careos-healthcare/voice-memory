import type {
  BlindSpotFeedbackRecord,
  BlindSpotMetrics,
  BlindSpotPerformanceRow,
  BlindSpotReaction,
  BlindSpotValidationReport,
  EvidenceStrengthLabel,
  EvidenceStrengthReactionBucket,
} from "@/types/blind-spot";

const SELF_RECOGNITION: BlindSpotReaction[] = [
  "interesting",
  "surprising",
  "uncomfortably_accurate",
];

const FAILURE: BlindSpotReaction[] = ["obvious", "completely_wrong"];

function rate(count: number, total: number): number {
  if (total === 0) return 0;
  return Math.round((count / total) * 1000) / 1000;
}

function countReaction(records: BlindSpotFeedbackRecord[], reaction: BlindSpotReaction): number {
  return records.filter((r) => r.reaction === reaction).length;
}

/** Aggregate self-recognition validation metrics from stored reactions. */
export function computeBlindSpotMetrics(
  records: BlindSpotFeedbackRecord[],
): BlindSpotMetrics {
  const total = records.length;
  const obvious = countReaction(records, "obvious");
  const interesting = countReaction(records, "interesting");
  const surprising = countReaction(records, "surprising");
  const uncomfortablyAccurate = countReaction(records, "uncomfortably_accurate");
  const completelyWrong = countReaction(records, "completely_wrong");

  return {
    totalReviews: total,
    obviousRate: rate(obvious, total),
    interestingRate: rate(interesting, total),
    surprisingRate: rate(surprising, total),
    uncomfortablyAccurateRate: rate(uncomfortablyAccurate, total),
    completelyWrongRate: rate(completelyWrong, total),
    selfRecognitionScore: interesting + surprising + uncomfortablyAccurate,
    holyShitScore: uncomfortablyAccurate,
    failureScore: obvious + completelyWrong,
  };
}

function groupByReviewId(
  records: BlindSpotFeedbackRecord[],
): Map<string, BlindSpotFeedbackRecord[]> {
  const map = new Map<string, BlindSpotFeedbackRecord[]>();
  for (const record of records) {
    const list = map.get(record.reviewId) ?? [];
    list.push(record);
    map.set(record.reviewId, list);
  }
  return map;
}

function performanceRow(
  reviewId: string,
  group: BlindSpotFeedbackRecord[],
): BlindSpotPerformanceRow {
  const headline = group[group.length - 1]?.headline ?? reviewId;
  let selfRecognitionCount = 0;
  let holyShitCount = 0;
  let failureCount = 0;

  for (const record of group) {
    if (SELF_RECOGNITION.includes(record.reaction)) selfRecognitionCount += 1;
    if (record.reaction === "uncomfortably_accurate") holyShitCount += 1;
    if (FAILURE.includes(record.reaction)) failureCount += 1;
  }

  return {
    reviewId,
    headline,
    reviewCount: group.length,
    selfRecognitionCount,
    holyShitCount,
    failureCount,
  };
}

export function rankBlindSpotPerformance(
  records: BlindSpotFeedbackRecord[],
): { top: BlindSpotPerformanceRow[]; worst: BlindSpotPerformanceRow[] } {
  const rows = [...groupByReviewId(records).entries()].map(([reviewId, group]) =>
    performanceRow(reviewId, group),
  );

  const top = [...rows]
    .sort(
      (a, b) =>
        b.selfRecognitionCount - a.selfRecognitionCount ||
        b.holyShitCount - a.holyShitCount ||
        b.reviewCount - a.reviewCount,
    )
    .slice(0, 5);

  const worst = [...rows]
    .sort(
      (a, b) =>
        b.failureCount - a.failureCount ||
        b.reviewCount - a.reviewCount ||
        a.selfRecognitionCount - b.selfRecognitionCount,
    )
    .filter((r) => r.failureCount > 0 || r.reviewCount > 0)
    .slice(0, 5);

  return { top, worst };
}

const STRENGTH_ORDER: EvidenceStrengthLabel[] = [
  "low",
  "medium",
  "high",
  "very_high",
];

export function evidenceStrengthCorrelation(
  records: BlindSpotFeedbackRecord[],
): EvidenceStrengthReactionBucket[] {
  const byStrength = new Map<EvidenceStrengthLabel, BlindSpotFeedbackRecord[]>();

  for (const record of records) {
    const list = byStrength.get(record.evidenceStrength) ?? [];
    list.push(record);
    byStrength.set(record.evidenceStrength, list);
  }

  return STRENGTH_ORDER.filter((s) => byStrength.has(s)).map((strength) => {
    const group = byStrength.get(strength) ?? [];
    const obvious = countReaction(group, "obvious");
    const interesting = countReaction(group, "interesting");
    const surprising = countReaction(group, "surprising");
    const uncomfortablyAccurate = countReaction(group, "uncomfortably_accurate");
    const completelyWrong = countReaction(group, "completely_wrong");

    return {
      evidenceStrength: strength,
      total: group.length,
      obvious,
      interesting,
      surprising,
      uncomfortablyAccurate,
      completelyWrong,
      selfRecognitionCount: interesting + surprising + uncomfortablyAccurate,
    };
  });
}

export function buildBlindSpotValidationReport(
  records: BlindSpotFeedbackRecord[],
): BlindSpotValidationReport {
  const { top, worst } = rankBlindSpotPerformance(records);
  return {
    metrics: computeBlindSpotMetrics(records),
    topPerforming: top,
    worstPerforming: worst,
    evidenceStrengthCorrelation: evidenceStrengthCorrelation(records),
    generatedAt: new Date().toISOString(),
  };
}
