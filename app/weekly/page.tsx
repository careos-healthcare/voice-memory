"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import {
  Activity,
  CalendarRange,
  LineChart,
  TrendingUp,
  Users,
} from "lucide-react";

import { FeedbackPrompt } from "@/components/FeedbackPrompt";
import { UpgradeCta } from "@/components/billing/UpgradeCta";
import { ExportSummaryButton } from "@/components/export/ExportSummaryButton";
import { ShareMemoryCardRow } from "@/components/memory/ShareMemoryCardButton";
import { SiteHeader } from "@/components/SiteHeader";
import { WeekComparisonCard } from "@/components/weekly/WeekComparisonCard";
import { WeeklyAiReflection } from "@/components/weekly/WeeklyAiReflection";
import {
  EntryTimelineChart,
  IntensityWeekChart,
  RankedListCard,
  TrendStatCard,
} from "@/components/weekly/WeeklyTrendCharts";
import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { WhyThisMatters } from "@/components/WhyThisMatters";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  analyzeWeeklyIntelligence,
  type WeeklyIntelligenceReport,
} from "@/lib/weekly-intelligence";
import { CalmUnderstandingCard } from "@/components/patterns/CalmUnderstandingCard";
import { SeeMorePanel } from "@/components/patterns/SeeMorePanel";
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { AvoidanceCard } from "@/components/patterns/AvoidanceCard";
import { EmotionalEvolutionCard } from "@/components/patterns/EmotionalEvolutionCard";
import {
  ContinuityChangeMomentsCard,
  LongitudinalContinuityCard,
} from "@/components/patterns/LongitudinalContinuityCard";
import { PatternInsightCard } from "@/components/patterns/PatternInsightCard";
import { PhraseMemoryCard } from "@/components/patterns/PhraseMemoryCard";
import { detectRecentContradictions } from "@/lib/patterns/contradictions";
import type { Contradiction } from "@/lib/patterns/contradictions";
import {
  detectRecentAvoidanceSignals,
  type AvoidanceSignal,
} from "@/lib/patterns/avoidance";
import {
  buildWeeklyEvolutionComparison,
  type WeeklyEvolutionComparison,
} from "@/lib/patterns/emotional-evolution";
import {
  buildPatternEngineReport,
  type PatternInsight,
} from "@/lib/patterns/pattern-engine";
import { getTopPhrases, type PhraseMemoryRecord } from "@/lib/patterns/phrase-memory";
import { getContinuityForWeekly } from "@/lib/patterns/continuity-engine";
import { buildCalmnessReport } from "@/lib/patterns/calmness";
import type { CalmnessReport } from "@/types/calmness";
import type { ContinuityReport } from "@/types/continuity";
import {
  hasStrongPatternEvidence,
  countsFromInsights,
} from "@/lib/patterns/evidence-priority";
import { getAllEntries } from "@/lib/storage";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";

const shiftAccent: Record<
  WeeklyIntelligenceReport["emotionalShift"]["direction"],
  string
> = {
  calmer: "text-emerald-300",
  intenser: "text-amber-300",
  stable: "text-zinc-300",
  mixed: "text-fuchsia-300",
  unknown: "text-zinc-500",
};

export default function WeeklyPage() {
  const [report, setReport] = useState<WeeklyIntelligenceReport | null>(null);
  const [contradictions, setContradictions] = useState<Contradiction[]>([]);
  const [avoidanceSignals, setAvoidanceSignals] = useState<AvoidanceSignal[]>([]);
  const [weekEvolution, setWeekEvolution] = useState<WeeklyEvolutionComparison | null>(null);
  const [patternInsights, setPatternInsights] = useState<PatternInsight[]>([]);
  const [phrases, setPhrases] = useState<PhraseMemoryRecord[]>([]);
  const [continuity, setContinuity] = useState<ContinuityReport | null>(null);
  const [calm, setCalm] = useState<CalmnessReport | null>(null);

  useEffect(() => {
    trackLaunchEvent(LAUNCH_EVENTS.weeklyPageOpened);
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setReport(analyzeWeeklyIntelligence());
      setContradictions(detectRecentContradictions(entries, 7));
      setAvoidanceSignals(detectRecentAvoidanceSignals(entries, 7));
      setWeekEvolution(buildWeeklyEvolutionComparison(entries));
      setPatternInsights(buildPatternEngineReport(entries, { scope: "weekly", limit: 8 }).insights);
      setPhrases(getTopPhrases(entries, 6));
      setContinuity(getContinuityForWeekly(entries, 8));
      setCalm(buildCalmnessReport(entries, { scope: "weekly", limit: 3 }));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = report === null;
  const strongPatterns = report
    ? hasStrongPatternEvidence({
        ...countsFromInsights(patternInsights),
        contradictionCount: contradictions.length,
        phraseCount: phrases.length,
        avoidanceCount: avoidanceSignals.length,
        evolutionCount: (weekEvolution?.insights.length ?? 0) + (weekEvolution?.lines.length ?? 0),
      })
    : false;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Weekly</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">This week</h1>
          <p className="mt-3 text-sm leading-relaxed text-zinc-500">
            What shifted in the last seven days — read quietly, not analyzed constantly.
          </p>
          {!loading && report ? (
            <>
              <p className="mt-2 flex items-center gap-2 text-xs text-zinc-500">
                <CalendarRange className="h-3.5 w-3.5" />
                {report.weekRangeLabel}
              </p>
              {report.hasData ? (
                <div className="mt-4 flex flex-wrap gap-2">
                  <ExportSummaryButton variant="weekly" />
                  <Button asChild variant="ghost" size="sm">
                    <Link href="/export">All export options</Link>
                  </Button>
                </div>
              ) : null}
            </>
          ) : null}
        </motion.div>

        <div className="mt-12 space-y-12">
          <UpgradeCta
            source="weekly"
            feature="weekly_intelligence"
            headline="Weekly intelligence on your full story"
            description="See emotional shifts, comparisons, and weekly memory summaries across your full reflection history — not just your latest seven."
          />

          {loading ? (
            <Card>
              <CardContent className="py-12 text-center text-sm text-zinc-500">
                Reading your local memory…
              </CardContent>
            </Card>
          ) : !report.hasData ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <Card className="border-dashed">
                <CardContent className="px-6 py-12 text-center">
                  <LineChart className="mx-auto h-8 w-8 text-violet-300" />
                  <p className="mt-4 text-lg font-medium text-white">
                    No reflections this week
                  </p>
                  <p className="mt-2 text-sm text-zinc-400">
                    Add a voice reflection in the last 7 days to unlock weekly
                    memory intelligence.
                  </p>
                  <Button asChild className="mt-6 w-full sm:w-auto">
                    <Link href="/">Record today&apos;s reflection</Link>
                  </Button>
                </CardContent>
              </Card>
            </>
          ) : (
            <>
              {calm?.hasData ? (
                <CalmUnderstandingCard
                  report={calm}
                  title="What stands out"
                  subtitle={report.weekRangeLabel}
                  showLandmarks
                />
              ) : null}

              <SeeMorePanel label="See more detail">
                <PatternInsightCard
                  insights={patternInsights}
                  title="Further patterns"
                  maxItems={6}
                  primaryCount={2}
                />
                <ContradictionContinuityCard
                  contradictions={contradictions}
                  title="Tension this week"
                  subtitle=""
                  maxItems={2}
                />
                <PhraseMemoryCard
                  phrases={phrases}
                  title="Repeated language"
                  maxItems={4}
                />
                <AvoidanceCard
                  signals={avoidanceSignals}
                  title="What stayed vague"
                  maxItems={3}
                />
                <EmotionalEvolutionCard
                  insights={weekEvolution?.insights ?? []}
                  weekComparison={weekEvolution}
                  showWeekComparison
                  title="This week vs last"
                  subtitle=""
                  maxItems={3}
                />
                {continuity?.hasData ? (
                  <>
                    <ContinuityChangeMomentsCard
                      report={continuity}
                      title="Change moments"
                      maxItems={3}
                    />
                    <LongitudinalContinuityCard
                      report={continuity}
                      title="Continuity"
                      subtitle=""
                      maxItems={4}
                      showSummaries={false}
                      showArcs
                      showIdentity={false}
                    />
                  </>
                ) : null}
                <RankedListCard
                  title="Recurring themes"
                  subtitle=""
                  items={report.thisWeek.recurringThemes}
                  emptyLabel=""
                  capitalize
                />
                <RankedListCard
                  title="People & entities"
                  subtitle=""
                  items={report.thisWeek.repeatedEntities}
                  emptyLabel=""
                  capitalize
                />
                <WeekComparisonCard
                  comparison={report.comparison}
                  thisWeekLabel={report.weekRangeLabel}
                  lastWeekLabel={report.previousWeekRangeLabel}
                />
                {!strongPatterns ? (
                  <>
                    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                      <TrendStatCard
                        label="Entries"
                        value={String(report.thisWeek.entryCount)}
                        hint="Last 7 days"
                      />
                      <TrendStatCard
                        label="Avg intensity"
                        value={
                          report.thisWeek.avgIntensity !== null
                            ? `${report.thisWeek.avgIntensity}/10`
                            : "—"
                        }
                      />
                      <div className="col-span-2 sm:col-span-1">
                        <TrendStatCard
                          label="Top mood"
                          value={
                            report.thisWeek.dominantEmotions[0]?.label ?? "—"
                          }
                          hint="Dominant emotion"
                        />
                      </div>
                    </div>
                    <Card
                      className={
                        report.emotionalShift.direction === "calmer"
                          ? "border-emerald-500/20 bg-emerald-500/5"
                          : report.emotionalShift.direction === "intenser"
                            ? "border-amber-500/20 bg-amber-500/5"
                            : "border-white/10"
                      }
                    >
                      <CardHeader className="pb-2">
                        <div className="flex items-center gap-2">
                          <TrendingUp
                            className={`h-4 w-4 ${shiftAccent[report.emotionalShift.direction]}`}
                          />
                          <CardTitle className="text-base">Emotional shift</CardTitle>
                        </div>
                        <p className="text-xs text-zinc-500">Vs previous 7 days</p>
                      </CardHeader>
                      <CardContent>
                        <p
                          className={`text-sm font-medium ${shiftAccent[report.emotionalShift.direction]}`}
                        >
                          {report.emotionalShift.label}
                        </p>
                        <p className="mt-2 text-sm leading-relaxed text-zinc-400">
                          {report.emotionalShift.detail}
                        </p>
                        {report.emotionalShift.intensityDelta !== null ? (
                          <Badge className="mt-3" variant="secondary">
                            Δ intensity{" "}
                            {report.emotionalShift.intensityDelta > 0 ? "+" : ""}
                            {report.emotionalShift.intensityDelta}
                          </Badge>
                        ) : null}
                      </CardContent>
                    </Card>
                  </>
                ) : null}
                <Card>
                  <CardHeader className="pb-2">
                    <div className="flex items-center gap-2">
                      <LineChart className="h-4 w-4 text-violet-300" />
                      <CardTitle className="text-base">Intensity trend</CardTitle>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <IntensityWeekChart points={report.thisWeek.intensityByDay} />
                  </CardContent>
                </Card>
                <Card>
                  <CardHeader className="pb-2">
                    <div className="flex items-center gap-2">
                      <Activity className="h-4 w-4 text-fuchsia-300" />
                      <CardTitle className="text-base">Reflection timeline</CardTitle>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <EntryTimelineChart points={report.thisWeek.entryTimeline} />
                  </CardContent>
                </Card>
                {!strongPatterns ? (
                  <RankedListCard
                    title="Dominant emotions"
                    subtitle=""
                    items={report.thisWeek.dominantEmotions}
                    emptyLabel=""
                    capitalize
                  />
                ) : null}
                <WeeklyAiReflection report={report} />
              </SeeMorePanel>

              <FeedbackPrompt
                kind="weekly_summary"
                targetKey={report.weekEndingKey}
                label="Did this week's read feel useful?"
              />

              <ShareMemoryCardRow
                kinds={["weekly_summary", "timeline_compression", "memory_continuity", "dominant_theme"]}
              />

              <div className="flex items-center gap-2 rounded-2xl border border-white/5 px-4 py-3 text-xs text-zinc-600">
                <Users className="h-3.5 w-3.5 shrink-0" />
                Computed locally from your transcripts.
              </div>

              <WhyThisMatters compact />
            </>
          )}
        </div>
      </div>
    </div>
  );
}
