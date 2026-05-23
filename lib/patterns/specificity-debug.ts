import {
  buildPatternEngineReport,
  type PatternInsight,
} from "@/lib/patterns/pattern-engine";

export interface SpecificityDebugReport {
  insights: PatternInsight[];
  weakInsights: PatternInsight[];
  strongInsights: PatternInsight[];
  generatedAt: string;
  averageSpecificity: number;
}

/** Build debug report for specificity scoring across the archive. */
export function buildSpecificityDebugReport(
  entries: Parameters<typeof buildPatternEngineReport>[0],
  limit = 20,
): SpecificityDebugReport {
  const report = buildPatternEngineReport(entries, { scope: "archive", limit });
  const insights = report.insights;
  const weakInsights = insights.filter((i) => i.specificity.isWeakOrGeneric);
  const strongInsights = insights.filter((i) => !i.specificity.isWeakOrGeneric);
  const averageSpecificity =
    insights.length > 0
      ? Math.round(
          insights.reduce((sum, i) => sum + i.specificity.specificityScore, 0) /
            insights.length,
        )
      : 0;

  return {
    insights,
    weakInsights,
    strongInsights,
    generatedAt: report.generatedAt,
    averageSpecificity,
  };
}
