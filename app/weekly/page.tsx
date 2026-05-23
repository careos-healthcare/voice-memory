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
  Shield,
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
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { AvoidanceCard } from "@/components/patterns/AvoidanceCard";
import { EmotionalEvolutionCard } from "@/components/patterns/EmotionalEvolutionCard";
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

  useEffect(() => {
    trackLaunchEvent(LAUNCH_EVENTS.weeklyPageOpened);
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setReport(analyzeWeeklyIntelligence());
      setContradictions(detectRecentContradictions(entries, 7));
      setAvoidanceSignals(detectRecentAvoidanceSignals(entries, 7));
      setWeekEvolution(buildWeeklyEvolutionComparison(entries));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = report === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            Weekly memory intelligence
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Your week in memory
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Rolling 7-day patterns — emotional shifts, repeated language, and
            contradictions compared to the week before. Local only.
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

        <div className="mt-6 space-y-5">
          <div className="flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-xs text-zinc-500">
            <Shield className="mt-0.5 h-4 w-4 shrink-0 text-zinc-400" />
            Reflective mirror only — not therapy, not a diagnosis. Weekly patterns
            describe what you said, not clinical labels.
          </div>

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

              <EmotionalEvolutionCard
                insights={weekEvolution?.insights ?? []}
                weekComparison={weekEvolution}
                showWeekComparison
                title="This week vs previous week"
                subtitle="Intensity shift and topic-level changes from your words"
                maxItems={4}
              />

              <ContradictionContinuityCard
                contradictions={contradictions}
                title="This week's contradictions"
                subtitle="Tension and reversals from the last 7 days — not a diagnosis"
                maxItems={4}
              />

              <AvoidanceCard
                signals={avoidanceSignals}
                title="What stays vague this week"
                subtitle="Indirect language from the last 7 days — not a clinical claim"
                maxItems={4}
              />

              <WeekComparisonCard
                comparison={report.comparison}
                thisWeekLabel={report.weekRangeLabel}
                lastWeekLabel={report.previousWeekRangeLabel}
              />

              <WeeklyAiReflection report={report} />

              <FeedbackPrompt
                kind="weekly_summary"
                targetKey={report.weekEndingKey}
                label="Were these weekly pattern observations useful?"
              />

              <ShareMemoryCardRow
                kinds={["weekly_summary", "timeline_compression", "memory_continuity", "dominant_theme"]}
              />

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <LineChart className="h-4 w-4 text-violet-300" />
                    <CardTitle className="text-base">
                      Emotional intensity trend
                    </CardTitle>
                  </div>
                  <p className="text-xs text-zinc-500">Daily average · this week</p>
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
                  <p className="text-xs text-zinc-500">
                    Dots sized by entries per day
                  </p>
                </CardHeader>
                <CardContent>
                  <EntryTimelineChart points={report.thisWeek.entryTimeline} />
                </CardContent>
              </Card>

              <RankedListCard
                title="Recurring themes"
                subtitle="Patterns that kept returning"
                items={report.thisWeek.recurringThemes}
                emptyLabel="Themes appear as you add voice reflections."
                capitalize
              />

              <RankedListCard
                title="People & entities"
                subtitle="Names and relationships you mentioned"
                items={report.thisWeek.repeatedEntities}
                emptyLabel="No names or relationships surfaced this week."
                capitalize
              />

              <RankedListCard
                title="Dominant emotions"
                subtitle="How you described feeling — not a diagnosis"
                items={report.thisWeek.dominantEmotions}
                emptyLabel="No mood data this week."
                capitalize
              />

              <div className="flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-3 text-xs text-zinc-500">
                <Users className="h-3.5 w-3.5 shrink-0" />
                Entity detection runs locally on your transcripts — nothing leaves
                this device except optional weekly intelligence summaries.
              </div>

              <WhyThisMatters compact />
            </>
          )}
        </div>
      </div>
    </div>
  );
}
