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
  Shield,
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
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { PhraseMemoryCard } from "@/components/patterns/PhraseMemoryCard";
import { analyzeJournalEntries, type MemoryInsights } from "@/lib/journal-analytics";
import { detectAllContradictions, type Contradiction } from "@/lib/patterns/contradictions";
import { getTopPhrases, type PhraseMemoryRecord } from "@/lib/patterns/phrase-memory";
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

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setInsights(analyzeJournalEntries());
      setContradictions(detectAllContradictions(entries));
      setPhrases(getTopPhrases(entries, 10));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = insights === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-16 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            Pattern intelligence
          </p>
          <h1 className="mt-2 text-3xl font-semibold text-white">Insights</h1>
          <p className="mt-2 text-sm text-zinc-400">
            Recurring patterns, repeated language, and emotional shifts — computed
            locally from your words.
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

        <div className="mt-6 flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
          <Shield className="mt-0.5 h-4 w-4 shrink-0 text-zinc-400" />
          <p className="text-xs leading-relaxed text-zinc-500">
            Reflective mirror only — not therapy, not a diagnosis. These are
            patterns in what you said, not clinical labels.
          </p>
        </div>

        <div className="mt-8 space-y-6">
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

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <Tag className="h-4 w-4 text-violet-300" />
                    <CardTitle className="text-base">Recurring themes</CardTitle>
                  </div>
                  <p className="text-xs text-zinc-500">Topics that keep returning in your words</p>
                </CardHeader>
                <CardContent className="flex flex-wrap gap-2">
                  {insights.recurringThemes.map((row) => (
                    <Badge key={row.theme} variant="secondary" className="capitalize">
                      {row.theme} · {row.count}
                    </Badge>
                  ))}
                </CardContent>
              </Card>

              <ContradictionContinuityCard
                contradictions={contradictions}
                title="Contradictions across your archive"
                subtitle="Conflicting statements, reversals, and tension between aims and behavior"
                maxItems={5}
              />

              <PhraseMemoryCard
                phrases={phrases}
                title="Repeated language"
                subtitle="Phrases, metaphors, and self-labels that recur across your archive"
                maxItems={10}
              />

              {insights.weeklyMentions.length > 0 ? (
                <Card className="border-violet-400/20 bg-violet-500/5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-base">Evidence from this week</CardTitle>
                    <p className="text-xs text-zinc-500">What showed up repeatedly in the last 7 days</p>
                  </CardHeader>
                  <CardContent className="space-y-2">
                    {insights.weeklyMentions.map((mention) => (
                      <p key={mention.label} className="text-sm text-zinc-300">
                        You mentioned{" "}
                        <span className="font-medium capitalize text-white">
                          {mention.label}
                        </span>{" "}
                        <span className="text-violet-300">
                          {mention.count} time{mention.count === 1 ? "" : "s"}
                        </span>{" "}
                        this week
                      </p>
                    ))}
                    <ShareMemoryCardButton kind="memory_continuity" className="mt-4 border-violet-500/20" />
                    <FeedbackPrompt
                      kind="memory_continuity"
                      targetKey="global"
                      label="Were these pattern observations useful?"
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
                    label="Were these pattern observations useful?"
                    className="mt-4"
                  />
                </>
              )}

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <MessageSquareQuote className="h-4 w-4 text-emerald-300" />
                    <CardTitle className="text-base">Observations over time</CardTitle>
                  </div>
                  <p className="text-xs text-zinc-500">Concrete pattern notes from recent entries</p>
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

              <ShareMemoryCardButton kind="dominant_theme" />

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <LineChart className="h-4 w-4 text-sky-300" />
                    <CardTitle className="text-base">Emotional intensity trend</CardTitle>
                  </div>
                  <p className="text-xs text-zinc-500">Last 14 days · average per day</p>
                </CardHeader>
                <CardContent>
                  <IntensityTrendChart points={insights.intensityTrend} />
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <ArrowLeftRight className="h-4 w-4 text-fuchsia-300" />
                    <CardTitle className="text-base">Mood distribution</CardTitle>
                  </div>
                  <p className="text-xs text-zinc-500">How you described feeling — not a diagnosis</p>
                </CardHeader>
                <CardContent className="flex flex-wrap gap-2">
                  {insights.dominantMoods.map((row) => (
                    <Badge key={row.mood} variant="default" className="capitalize">
                      {row.mood} · {row.count} ({row.share}%)
                    </Badge>
                  ))}
                </CardContent>
              </Card>

              <WhyThisMatters compact />
            </>
          )}
        </div>
      </div>
    </div>
  );
}
