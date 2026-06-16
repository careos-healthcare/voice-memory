import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { readAllBreakthroughCaptures } from "@/lib/blind-spots/breakthrough-capture";
import {
  averageWowMomentScore,
  wowMomentScoreForReaction,
} from "@/lib/blind-spots/wow-moment-score";
import { toDayKey } from "@/lib/dates";
import { readFirstValueSnapshot } from "@/lib/retention/first-value-moments";
import {
  RETURN_REASON_LABELS,
  RETURN_REASON_OPTIONS,
  readAllReturnReasons,
} from "@/lib/retention/return-reason-survey";
import { readSessionRetentionSnapshot } from "@/lib/retention/session-retention";
import {
  helpfulnessScore,
  readAllSessionOutcomes,
} from "@/lib/retention/session-outcome";
import type {
  RetentionDiscoveryReport,
  RetentionInsightLine,
  RetentionSignalScore,
  ReturnReason,
  ReturnReasonBreakdown,
} from "@/types/retention-discovery";

function average(nums: number[]): number {
  if (nums.length === 0) return 0;
  return Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 100) / 100;
}

function wowOnDay(dayKey: string): number[] {
  return readAllBlindSpotFeedback()
    .filter((f) => toDayKey(f.at) === dayKey)
    .map((f) => wowMomentScoreForReaction(f.reaction));
}

function buildReturnReasonBreakdowns(): ReturnReasonBreakdown[] {
  const reasons = readAllReturnReasons();
  const outcomes = readAllSessionOutcomes();
  const total = reasons.length || 1;

  return RETURN_REASON_OPTIONS.map((reason) => {
    const rows = reasons.filter((r) => r.reason === reason);
    const count = rows.length;
    const helpfulnessBySession = rows.map((r) => {
      const match = outcomes.find((o) => o.sessionNumber === r.sessionNumber);
      return match ? helpfulnessScore(match.outcome) : null;
    });
    const helpfulnessValues = helpfulnessBySession.filter(
      (v): v is number => v !== null,
    );
    const wowValues = rows.flatMap((r) => wowOnDay(toDayKey(r.at)));

    return {
      reason,
      label: RETURN_REASON_LABELS[reason],
      count,
      share: Math.round((count / total) * 100),
      averageWowScore: average(wowValues),
      averageHelpfulness: average(helpfulnessValues),
      averageArchiveSize: average(rows.map((r) => r.archiveSize)),
    };
  }).filter((row) => row.count > 0);
}

function buildSignalScore(): RetentionSignalScore {
  const reasons = readAllReturnReasons();
  const outcomes = readAllSessionOutcomes();
  const feedback = readAllBlindSpotFeedback();
  const breakthroughs = readAllBreakthroughCaptures();
  const snapshot = readSessionRetentionSnapshot();

  const sessionCount = Math.max(
    snapshot.sessionCount,
    ...reasons.map((r) => r.sessionNumber),
    0,
  );
  const returnRate =
    sessionCount > 0
      ? Math.round((reasons.length / sessionCount) * 100)
      : 0;

  const strongReactions = feedback.filter(
    (f) => f.reaction === "surprising" || f.reaction === "uncomfortably_accurate",
  ).length;
  const breakthroughRate =
    strongReactions > 0
      ? Math.round((breakthroughs.length / strongReactions) * 100)
      : 0;

  const abandonmentSignalRate =
    outcomes.length > 0
      ? Math.round(
          (outcomes.filter((o) => o.outcome === "not_really").length / outcomes.length) *
            100,
        )
      : 0;

  return {
    returnRate,
    sessionCount,
    returnReasonCount: reasons.length,
    averageWowScore: averageWowMomentScore(feedback.map((f) => f.reaction)),
    averageHelpfulness: average(outcomes.map((o) => helpfulnessScore(o.outcome))),
    breakthroughRate,
    abandonmentSignalRate,
  };
}

function sessionBucket(sessionNumber: number): string {
  if (sessionNumber <= 1) return "session_1";
  if (sessionNumber <= 3) return "session_2_3";
  return "session_4_plus";
}

function buildInsights(
  breakdowns: ReturnReasonBreakdown[],
  signal: RetentionSignalScore,
): RetentionInsightLine[] {
  const reasons = readAllReturnReasons();
  const outcomes = readAllSessionOutcomes();
  const breakthroughs = readAllBreakthroughCaptures();

  const top =
    [...breakdowns].sort((a, b) => b.count - a.count)[0] ?? null;

  const byWow = [...breakdowns].sort((a, b) => b.averageWowScore - a.averageWowScore)[0];
  const byHelp = [...breakdowns].sort(
    (a, b) => b.averageHelpfulness - a.averageHelpfulness,
  )[0];
  const byAbandon = [...breakdowns]
    .filter((b) => b.averageHelpfulness > 0)
    .sort((a, b) => a.averageHelpfulness - b.averageHelpfulness)[0];

  const secondPlus = reasons.filter((r) => r.sessionNumber >= 2);
  const topReturnSecond =
    secondPlus.length > 0
      ? Object.entries(
          secondPlus.reduce<Record<string, number>>((acc, r) => {
            acc[r.reason] = (acc[r.reason] ?? 0) + 1;
            return acc;
          }, {}),
        ).sort((a, b) => b[1] - a[1])[0]
      : null;

  const bucketLines = ["session_1", "session_2_3", "session_4_plus"].map((bucket) => {
    const inBucket = reasons.filter((r) => sessionBucket(r.sessionNumber) === bucket);
    if (inBucket.length === 0) return `${bucket}: no data`;
    const counts = inBucket.reduce<Record<string, number>>((acc, r) => {
      acc[r.reason] = (acc[r.reason] ?? 0) + 1;
      return acc;
    }, {});
    const leader = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
    return `${bucket}: ${leader ? RETURN_REASON_LABELS[leader[0] as ReturnReason] : "—"} (${leader?.[1] ?? 0})`;
  });

  const correlations: RetentionInsightLine[] = [
    {
      question: "Why do people return?",
      answer: top
        ? `Most common return reason: ${top.label} (${top.share}% of captures).`
        : "No return reasons captured yet.",
    },
    {
      question: "What predicts return?",
      answer: topReturnSecond
        ? `Among session 2+, top reason: ${RETURN_REASON_LABELS[topReturnSecond[0] as ReturnReason]}. Return capture rate ${signal.returnRate}% across ${signal.sessionCount} sessions. ${bucketLines.join(" · ")}`
        : `Return capture rate ${signal.returnRate}% — need more sessions.`,
    },
    {
      question: "What predicts breakthrough?",
      answer: `Breakthrough capture rate ${signal.breakthroughRate}% of strong reactions (${breakthroughs.length} captures).${
        byWow && byWow.count > 0
          ? ` Highest same-day wow among return reasons: ${byWow.label} (avg ${byWow.averageWowScore}).`
          : ""
      }`,
    },
    {
      question: "What predicts abandonment?",
      answer: `“Not really” session outcomes: ${signal.abandonmentSignalRate}%.${
        byAbandon && byAbandon.count > 0
          ? ` Lowest helpfulness among return reasons with data: ${byAbandon.label} (avg ${byAbandon.averageHelpfulness}).`
          : ""
      }${outcomes.length === 0 ? " No session outcomes yet." : ""}`,
    },
    {
      question: "Correlations (measurement only)",
      answer: [
        `Avg wow (all reactions): ${signal.averageWowScore}`,
        `Avg helpfulness: ${signal.averageHelpfulness}`,
        byHelp && byHelp.count > 0
          ? `Strongest helpfulness by return reason: ${byHelp.label}`
          : null,
      ]
        .filter(Boolean)
        .join(" · "),
    },
  ];

  return correlations;
}

export function buildRetentionDiscoveryReport(): RetentionDiscoveryReport {
  const returnReasons = buildReturnReasonBreakdowns();
  const mostCommonReturnReason =
    returnReasons.length > 0
      ? [...returnReasons].sort((a, b) => b.count - a.count)[0]!.reason
      : null;

  const signalScore = buildSignalScore();

  return {
    generatedAt: new Date().toISOString(),
    returnReasons,
    mostCommonReturnReason,
    firstValue: readFirstValueSnapshot(),
    signalScore,
    insights: buildInsights(returnReasons, signalScore),
  };
}

/** Session-count buckets for the internal panel table. */
export function returnReasonBySessionBucket(): Record<string, ReturnReasonBreakdown[]> {
  const reasons = readAllReturnReasons();
  const buckets = ["session_1", "session_2_3", "session_4_plus"] as const;
  const result: Record<string, ReturnReasonBreakdown[]> = {};

  for (const bucket of buckets) {
    const inBucket = reasons.filter((r) => sessionBucket(r.sessionNumber) === bucket);
    const total = inBucket.length || 1;
    result[bucket] = RETURN_REASON_OPTIONS.map((reason) => {
      const rows = inBucket.filter((r) => r.reason === reason);
      return {
        reason,
        label: RETURN_REASON_LABELS[reason],
        count: rows.length,
        share: Math.round((rows.length / total) * 100),
        averageWowScore: average(rows.flatMap((r) => wowOnDay(toDayKey(r.at)))),
        averageHelpfulness: average(
          rows
            .map((r) => {
              const match = readAllSessionOutcomes().find(
                (o) => o.sessionNumber === r.sessionNumber,
              );
              return match ? helpfulnessScore(match.outcome) : null;
            })
            .filter((v): v is number => v !== null),
        ),
        averageArchiveSize: average(rows.map((r) => r.archiveSize)),
      };
    }).filter((row) => row.count > 0);
  }

  return result;
}
