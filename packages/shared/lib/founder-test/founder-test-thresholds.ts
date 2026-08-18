import type { FounderTestReport, FounderTestStudySignal } from "@/types/founder-test";

export const FOUNDER_TEST_STRONG_THRESHOLDS = {
  reachedFiveRate: 60,
  surprisingOrAccurateRate: 30,
  sevenDayReturnRate: 30,
  chatGptDifferenceUnderstoodRate: 50,
  wouldPayRate: 20,
} as const;

export const FOUNDER_TEST_WEAK_THRESHOLDS = {
  reachedFiveRate: 40,
  surprisingOrAccurateRate: 15,
  sevenDayReturnRate: 20,
  chatGptDifferenceUnderstoodRate: 30,
} as const;

export const FOUNDER_TEST_STUDY_SIGNAL_LABELS: Record<FounderTestStudySignal, string> = {
  strong_signal: "Strong signal — study metrics meet founder thresholds",
  mixed_signal: "Mixed signal — some traction, not enough to call product-market fit",
  weak_signal: "Weak signal — revisit onboarding and the ChatGPT differentiation story",
};

function below(rate: number | null, threshold: number): boolean {
  return rate !== null && rate < threshold;
}

function meetsStrong(rate: number | null, threshold: number): boolean {
  return rate !== null && rate >= threshold;
}

export function classifyFounderTestStudySignal(
  report: Pick<
    FounderTestReport,
    | "totalParticipants"
    | "reachedFiveRate"
    | "surprisingOrAccurateRate"
    | "sevenDayReturnRate"
    | "chatGptDifferenceUnderstoodRate"
    | "wouldPayRate"
  >,
): FounderTestStudySignal {
  if (report.totalParticipants < 3) {
    return "mixed_signal";
  }

  const weakHits = [
    below(report.reachedFiveRate, FOUNDER_TEST_WEAK_THRESHOLDS.reachedFiveRate),
    below(
      report.surprisingOrAccurateRate,
      FOUNDER_TEST_WEAK_THRESHOLDS.surprisingOrAccurateRate,
    ),
    below(report.sevenDayReturnRate, FOUNDER_TEST_WEAK_THRESHOLDS.sevenDayReturnRate),
    below(
      report.chatGptDifferenceUnderstoodRate,
      FOUNDER_TEST_WEAK_THRESHOLDS.chatGptDifferenceUnderstoodRate,
    ),
  ].filter(Boolean).length;

  if (weakHits >= 2) {
    return "weak_signal";
  }

  const strongHits = [
    meetsStrong(report.reachedFiveRate, FOUNDER_TEST_STRONG_THRESHOLDS.reachedFiveRate),
    meetsStrong(
      report.surprisingOrAccurateRate,
      FOUNDER_TEST_STRONG_THRESHOLDS.surprisingOrAccurateRate,
    ),
    meetsStrong(report.sevenDayReturnRate, FOUNDER_TEST_STRONG_THRESHOLDS.sevenDayReturnRate),
    meetsStrong(
      report.chatGptDifferenceUnderstoodRate,
      FOUNDER_TEST_STRONG_THRESHOLDS.chatGptDifferenceUnderstoodRate,
    ),
    meetsStrong(report.wouldPayRate, FOUNDER_TEST_STRONG_THRESHOLDS.wouldPayRate),
  ].filter(Boolean).length;

  if (strongHits >= 4) {
    return "strong_signal";
  }

  return "mixed_signal";
}
