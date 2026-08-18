import "server-only";

export type {
  ComparisonPeriodSnapshot,
  InsightTimeRange,
  ThenVsNowComparisonResult,
} from "@/src/services/insights/comparison";
export {
  COMPARISON_MIN_USABLE_ENTRIES_PER_RANGE,
  generateThenVsNowComparison,
  ThenVsNowComparisonBlockedError,
} from "@/src/services/insights/comparison";
