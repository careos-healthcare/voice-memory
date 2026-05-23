"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import {
  Activity,
  BarChart3,
  Heart,
  LineChart,
  Sparkles,
  Tag,
} from "lucide-react";

import { HabitLoopCard } from "@/components/HabitLoopCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { analyzeJournalEntries, type MemoryInsights } from "@/lib/journal-analytics";

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

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setInsights(analyzeJournalEntries());
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
            Memory timeline
          </p>
          <h1 className="mt-2 text-3xl font-semibold text-white">Insights</h1>
          <p className="mt-2 text-sm text-zinc-400">
            Patterns from your journal — analyzed on this device only.
          </p>
        </motion.div>

        <div className="mt-8 space-y-6">
          <HabitLoopCard />

          {loading ? null : !insights.hasData ? (
            <Card className="border-dashed">
              <CardContent className="px-6 py-12 text-center">
                <Sparkles className="mx-auto h-8 w-8 text-violet-300" />
                <p className="mt-4 text-lg font-medium text-white">No memories yet</p>
                <p className="mt-2 text-sm text-zinc-400">
                  Record a reflection to unlock your mood timeline and themes.
                </p>
                <Button asChild className="mt-6">
                  <Link href="/">Record your first entry</Link>
                </Button>
              </CardContent>
            </Card>
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

                {insights.mostMentionedConcern ? (
                  <Card>
                    <CardHeader className="pb-2">
                      <div className="flex items-center gap-2">
                        <Activity className="h-4 w-4 text-amber-300" />
                        <CardTitle className="text-base">Most mentioned concern</CardTitle>
                      </div>
                    </CardHeader>
                    <CardContent>
                      <p className="text-sm capitalize leading-relaxed text-zinc-300">
                        {insights.mostMentionedConcern}
                      </p>
                    </CardContent>
                  </Card>
                ) : null}
              </div>

              {insights.weeklyMentions.length > 0 ? (
                <Card className="border-violet-400/20 bg-violet-500/5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-base">This week in your words</CardTitle>
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
                  </CardContent>
                </Card>
              ) : null}

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <Heart className="h-4 w-4 text-fuchsia-300" />
                    <CardTitle className="text-base">Dominant moods</CardTitle>
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

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <LineChart className="h-4 w-4 text-emerald-300" />
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
                    <Sparkles className="h-4 w-4 text-emerald-300" />
                    <CardTitle className="text-base">Positive signals over time</CardTitle>
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  {insights.positiveSignalsOverTime.map((point) => (
                    <div
                      key={point.date}
                      className="border-l-2 border-emerald-500/40 pl-4"
                    >
                      <p className="text-xs text-zinc-500">
                        {point.label} · <span className="capitalize">{point.mood}</span>
                      </p>
                      <p className="mt-1 text-sm leading-relaxed text-zinc-300">
                        {point.signal}
                      </p>
                    </div>
                  ))}
                </CardContent>
              </Card>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
