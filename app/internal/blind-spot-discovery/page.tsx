"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { BlindSpotDiscoveryPanel } from "@/components/internal/BlindSpotDiscoveryPanel";
import { BlindSpotQualityPanel } from "@/components/internal/BlindSpotQualityPanel";
import { ATierQualityDashboardPanel } from "@/components/internal/ATierQualityDashboardPanel";
import { InsightIngredientOptimizerPanel } from "@/components/internal/InsightIngredientOptimizerPanel";
import { buildATierQualityDashboardReport } from "@/lib/blind-spots/a-tier-quality-dashboard";
import { BlindSpotExperimentLoopPanel } from "@/components/internal/BlindSpotExperimentLoopPanel";
import { BreakthroughTrackingPanel } from "@/components/internal/BreakthroughTrackingPanel";
import { InsightOutcomePanel } from "@/components/internal/InsightOutcomePanel";
import { InsightScorecardInternalPanel } from "@/components/internal/InsightScorecardInternalPanel";
import { buildInsightOutcomeReport } from "@/lib/insights/insight-outcome-report";
import { buildInsightScorecardReport } from "@/lib/insights/insight-scorecard-report";
import { SelfRecognitionIngredientsPanel } from "@/components/internal/SelfRecognitionIngredientsPanel";
import { buildBlindSpotExperimentLoopReport } from "@/lib/blind-spots/blind-spot-experiment-metrics";
import { buildBlindSpotQualityReport } from "@/lib/blind-spots/blind-spot-quality-report";
import { buildInsightIngredientOptimizerReport } from "@/lib/insights/insight-ingredient-optimizer-report";
import { buildBreakthroughTrackingReport } from "@/lib/breakthrough/breakthrough-tracking-report";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { buildSelfRecognitionIngredientsReport } from "@/lib/insights/self-recognition-ingredients";
import { buildSelfRecognitionAnalysis } from "@/lib/blind-spots/self-recognition-analysis";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { BlindSpotDiscoveryReport } from "@/types/blind-spot-discovery";
import type { BlindSpotQualityReport } from "@/types/blind-spot-quality";
import type { ATierQualityDashboardReport } from "@/types/a-tier-prioritization";
import type { InsightIngredientOptimizerReport } from "@/types/insight-ingredient-optimizer";
import type { InsightOutcomeReport } from "@/types/insight-outcome";
import type { SelfRecognitionIngredientsReport } from "@/types/self-recognition-ingredients";

export default function BlindSpotDiscoveryPage() {
  const entries = useMemo(() => getMemoryEligibleEntries(), []);
  const [report, setReport] = useState<BlindSpotDiscoveryReport | null>(null);
  const [ingredientsReport, setIngredientsReport] =
    useState<SelfRecognitionIngredientsReport | null>(null);
  const [breakthroughReport, setBreakthroughReport] = useState(
    () => buildBreakthroughTrackingReport(),
  );
  const [scorecardReport, setScorecardReport] = useState(() =>
    buildInsightScorecardReport(entries),
  );
  const [experimentLoopReport, setExperimentLoopReport] = useState(() =>
    buildBlindSpotExperimentLoopReport(),
  );
  const [outcomeReport, setOutcomeReport] = useState<InsightOutcomeReport | null>(() =>
    buildInsightOutcomeReport(),
  );
  const [qualityReport, setQualityReport] = useState<BlindSpotQualityReport | null>(() =>
    buildBlindSpotQualityReport(),
  );
  const [optimizerReport, setOptimizerReport] = useState<InsightIngredientOptimizerReport | null>(
    () => buildInsightIngredientOptimizerReport(),
  );
  const [aTierDashboard, setATierDashboard] = useState<ATierQualityDashboardReport | null>(() =>
    buildATierQualityDashboardReport(),
  );

  const refresh = () => {
    const feedback = readAllBlindSpotFeedback();
    setReport(buildSelfRecognitionAnalysis(feedback));
    setIngredientsReport(buildSelfRecognitionIngredientsReport(entries, { blindSpotFeedback: feedback }));
    setBreakthroughReport(buildBreakthroughTrackingReport());
    setScorecardReport(buildInsightScorecardReport(entries));
    setExperimentLoopReport(buildBlindSpotExperimentLoopReport());
    setOutcomeReport(buildInsightOutcomeReport());
    setQualityReport(buildBlindSpotQualityReport());
    setOptimizerReport(buildInsightIngredientOptimizerReport());
    setATierDashboard(buildATierQualityDashboardReport());
  };

  useEffect(() => {
    refresh();
  }, [entries]);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Discovery v2</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Blind spot discovery
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              What creates holy-shit self-recognition — wow scores, pattern types, evidence strength,
              and breakthrough language. Measurement only.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!report || !ingredientsReport ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-12">
            <SelfRecognitionIngredientsPanel report={ingredientsReport} />
            {qualityReport ? <BlindSpotQualityPanel report={qualityReport} /> : null}
            {aTierDashboard ? <ATierQualityDashboardPanel report={aTierDashboard} /> : null}
            {optimizerReport ? (
              <InsightIngredientOptimizerPanel report={optimizerReport} />
            ) : null}
            <InsightScorecardInternalPanel report={scorecardReport} />
            <BreakthroughTrackingPanel report={breakthroughReport} />
            <BlindSpotExperimentLoopPanel report={experimentLoopReport} />
            {outcomeReport ? <InsightOutcomePanel report={outcomeReport} /> : null}
            <BlindSpotDiscoveryPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/founder-test" className="text-violet-300 hover:text-violet-200">
            Founder user-study checklist
          </Link>
          <Link href="/internal/blind-spot-performance" className="text-violet-300 hover:text-violet-200">
            Performance →
          </Link>
          <Link href="/blind-spots" className="text-zinc-500 hover:text-zinc-300">
            Blind spots →
          </Link>
        </div>
      </div>
    </div>
  );
}
