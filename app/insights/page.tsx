"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import {
  ArrowLeftRight,
  BarChart3,
  LineChart,
  MessageSquareQuote,
  Repeat2,
  Tag,
} from "lucide-react";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { ExportSummaryButton } from "@/components/export/ExportSummaryButton";
import { FeedbackPrompt } from "@/components/FeedbackPrompt";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { ShareMemoryCardButton } from "@/components/memory/ShareMemoryCardButton";
import { SiteHeader } from "@/components/SiteHeader";
import { WhyThisMatters } from "@/components/WhyThisMatters";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { CalmUnderstandingCard } from "@/components/patterns/CalmUnderstandingCard";
import { SeeMorePanel } from "@/components/patterns/SeeMorePanel";
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { AvoidanceCard } from "@/components/patterns/AvoidanceCard";
import { PhraseMemoryCard } from "@/components/patterns/PhraseMemoryCard";
import { EmotionalEvolutionCard } from "@/components/patterns/EmotionalEvolutionCard";
import { PatternInsightCard } from "@/components/patterns/PatternInsightCard";
import { analyzeJournalEntries, type MemoryInsights } from "@/lib/journal-analytics";
import { detectAllContradictions, type Contradiction } from "@/lib/patterns/contradictions";
import { getTopPhrases, type PhraseMemoryRecord } from "@/lib/patterns/phrase-memory";
import {
  detectAllAvoidanceSignals,
  type AvoidanceSignal,
} from "@/lib/patterns/avoidance";
import {
  getEmotionalCycleInsights,
  type EvolutionInsight,
} from "@/lib/patterns/emotional-evolution";
import {
  buildPatternEngineReport,
  type PatternInsight,
} from "@/lib/patterns/pattern-engine";
import { buildCalmnessReport } from "@/lib/patterns/calmness";
import type { CalmnessReport } from "@/types/calmness";
import {
  hasStrongPatternEvidence,
  countsFromInsights,
} from "@/lib/patterns/evidence-priority";
import { getAllEntries } from "@/lib/storage";

function IntensityTrendChart({ points }: { points: MemoryInsights["intensityTrend"] }) {
  const withData = points.filter((p) => p.entryCount > 0);
  const maxIntensity = Math.max(10, ...withData.map((p) => p.avgIntensity), 1);

  return (
    <div className="flex items-end gap-1 overflow-x-auto pb-2 pt-4">
      {points.map((point) => {
        const height =
          point.entryCount > 0
            ? Math.max(8, (point.avgIntensity / maxIntensity) * 100)
            : 4;

        return (
          <div
            key={point.dayKey}
            className="flex min-w-[2rem] flex-1 flex-col items-center gap-2"
            title={`${point.label}: ${point.entryCount ? `${point.avgIntensity}/10` : "no entries"}`}
          >
            <div className="flex h-24 w-full items-end justify-center">
              <div
                className={`w-full max-w-[1.25rem] rounded-t-md ${
                  point.entryCount > 0
                    ? "bg-gradient-to-t from-violet-600 to-fuchsia-400"
                    : "bg-white/10"
                }`}
                style={{ height: `${height}%` }}
              />
            </div>
            <span className="text-[10px] leading-tight text-zinc-600">
              {point.label.split(" ")[0]}
            </span>
          </div>
        );
      })}
    </div>
  );
}

export default function InsightsPage() {
  const [insights, setInsights] = useState<MemoryInsights | null>(null);
  const [contradictions, setContradictions] = useState<Contradiction[]>([]);
  const [phrases, setPhrases] = useState<PhraseMemoryRecord[]>([]);
  const [avoidanceSignals, setAvoidanceSignals] = useState<AvoidanceSignal[]>([]);
  const [cycleInsights, setCycleInsights] = useState<EvolutionInsight[]>([]);
  const [patternInsights, setPatternInsights] = useState<PatternInsight[]>([]);
  const [calm, setCalm] = useState<CalmnessReport | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setInsights(analyzeJournalEntries());
      setContradictions(detectAllContradictions(entries));
      setPhrases(getTopPhrases(entries, 10));
      setAvoidanceSignals(detectAllAvoidanceSignals(entries));
      setCycleInsights(getEmotionalCycleInsights(entries));
      setPatternInsights(buildPatternEngineReport(entries, { scope: "archive", limit: 10 }).insights);
      setCalm(buildCalmnessReport(entries, { scope: "archive", limit: 3 }));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = insights === null;
  const strongPatterns = hasStrongPatternEvidence({
    ...countsFromInsights(patternInsights),
    contradictionCount: contradictions.length,
    phraseCount: phrases.length,
    avoidanceCount: avoidanceSignals.length,
    evolutionCount: cycleInsights.length,
  });

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-16 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Patterns</p>
          <h1 className="mt-3 text-3xl font-semibold text-white">Insights</h1>
          <p className="mt-3 text-sm text-zinc-500">
            What repeats and what fades across your archive — held locally, read quietly.
          </p>
          {!loading && insights?.hasData ? (
            <div className="mt-4 flex flex-wrap gap-2">
              <ExportSummaryButton variant="insights" />
              <Button asChild variant="ghost" size="sm">
                <Link href="/export">All export options</Link>
              </Button>
            </div>
          ) : null}
        </motion.div>

        <div className="mt-12 space-y-12">
          <HabitLoopCard />

          {loading ? null : !insights.hasData ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <Card className="border-dashed">
                <CardContent className="px-6 py-12 text-center">
                  <Repeat2 className="mx-auto h-8 w-8 text-violet-300" />
                  <p className="mt-4 text-lg font-medium text-white">No patterns yet</p>
                  <p className="mt-2 text-sm text-zinc-400">
                    Add voice reflections to see recurring themes, repeated phrases,
                    and evidence from past entries.
                  </p>
                  <Button asChild className="mt-6">
                    <Link href="/">Add your first reflection</Link>
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
                  title="Tension across entries"
                  subtitle=""
                  maxItems={3}
                />
                <PhraseMemoryCard
                  phrases={phrases}
                  title="Repeated language"
                  maxItems={5}
                />
                <AvoidanceCard
                  signals={avoidanceSignals}
                  title="What stayed vague"
                  maxItems={4}
                />
                <EmotionalEvolutionCard
                  insights={cycleInsights}
                  title="Intensity over time"
                  maxItems={4}
                />
                {!strongPatterns || insights.recurringThemes.length > 0 ? (
                  <Card>
                    <CardHeader className="pb-2">
                      <div className="flex items-center gap-2">
                        <Tag className="h-4 w-4 text-violet-300" />
                        <CardTitle className="text-base">Recurring themes</CardTitle>
                      </div>
                    </CardHeader>
                    <CardContent className="flex flex-wrap gap-2">
                      {insights.recurringThemes.map((row) => (
                        <Badge key={row.theme} variant="secondary" className="capitalize">
                          {row.theme} · {row.count}
                        </Badge>
                      ))}
                    </CardContent>
                  </Card>
                ) : null}
                {!strongPatterns ? (
                  <div className="grid gap-4 sm:grid-cols-2">
                    <Card>
                      <CardHeader className="pb-2">
                        <div className="flex items-center gap-2">
                          <BarChart3 className="h-4 w-4 text-violet-300" />
                          <CardTitle className="text-base">Total entries</CardTitle>
                        </div>
                      </CardHeader>
                      <CardContent>
                        <p className="text-4xl font-semibold tabular-nums text-white">
                          {insights.totalEntries}
                        </p>
                      </CardContent>
                    </Card>
                    {insights.mostRepeatedPattern ? (
                      <Card>
                        <CardHeader className="pb-2">
                          <div className="flex items-center gap-2">
                            <Repeat2 className="h-4 w-4 text-fuchsia-300" />
                            <CardTitle className="text-base">Most repeated pattern</CardTitle>
                          </div>
                        </CardHeader>
                        <CardContent>
                          <p className="text-sm capitalize leading-relaxed text-zinc-300">
                            {insights.mostRepeatedPattern}
                          </p>
                        </CardContent>
                      </Card>
                    ) : null}
                  </div>
                ) : null}
                <Card>
                  <CardHeader className="pb-2">
                    <div className="flex items-center gap-2">
                      <LineChart className="h-4 w-4 text-sky-300" />
                      <CardTitle className="text-base">Intensity trend</CardTitle>
                    </div>
                    <p className="text-xs text-zinc-500">Last 14 days</p>
                  </CardHeader>
                  <CardContent>
                    <IntensityTrendChart points={insights.intensityTrend} />
                  </CardContent>
                </Card>
                {!strongPatterns ? (
                  <>
                    <Card>
                      <CardHeader className="pb-2">
                        <div className="flex items-center gap-2">
                          <ArrowLeftRight className="h-4 w-4 text-fuchsia-300" />
                          <CardTitle className="text-base">Mood distribution</CardTitle>
                        </div>
                      </CardHeader>
                      <CardContent className="flex flex-wrap gap-2">
                        {insights.dominantMoods.map((row) => (
                          <Badge key={row.mood} variant="default" className="capitalize">
                            {row.mood} · {row.count} ({row.share}%)
                          </Badge>
                        ))}
                      </CardContent>
                    </Card>
                    {insights.observationsOverTime.length > 0 ? (
                      <Card>
                        <CardHeader className="pb-2">
                          <div className="flex items-center gap-2">
                            <MessageSquareQuote className="h-4 w-4 text-emerald-300" />
                            <CardTitle className="text-base">Observations over time</CardTitle>
                          </div>
                        </CardHeader>
                        <CardContent className="space-y-4">
                          {insights.observationsOverTime.map((point) => (
                            <div
                              key={point.date}
                              className="border-l-2 border-emerald-500/40 pl-4"
                            >
                              <p className="text-xs text-zinc-500">
                                {point.label} · <span className="capitalize">{point.mood}</span>
                              </p>
                              <p className="mt-1 text-sm leading-relaxed text-zinc-300">
                                {point.observation}
                              </p>
                            </div>
                          ))}
                        </CardContent>
                      </Card>
                    ) : null}
                  </>
                ) : null}
              </SeeMorePanel>

              {insights.weeklyMentions.length > 0 ? (
                <Card className="border-white/5 bg-transparent">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-base text-zinc-400">This week</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-2">
                    {insights.weeklyMentions.map((mention) => (
                      <p key={mention.label} className="text-sm text-zinc-400">
                        You mentioned{" "}
                        <span className="font-medium capitalize text-zinc-200">
                          {mention.label}
                        </span>{" "}
                        {mention.count} time{mention.count === 1 ? "" : "s"}
                      </p>
                    ))}
                    <ShareMemoryCardButton kind="memory_continuity" className="mt-4 border-white/5" />
                    <FeedbackPrompt
                      kind="memory_continuity"
                      targetKey="global"
                      label="Did this read feel useful?"
                      className="mt-4"
                    />
                  </CardContent>
                </Card>
              ) : (
                <>
                  <ShareMemoryCardButton kind="memory_continuity" />
                  <FeedbackPrompt
                    kind="memory_continuity"
                    targetKey="global"
                    label="Did this read feel useful?"
                    className="mt-4"
                  />
                </>
              )}

              <ShareMemoryCardButton kind="dominant_theme" />

              <WhyThisMatters compact />
            </>
          )}
        </div>
      </div>
    </div>
  );
}
