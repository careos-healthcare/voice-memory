"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight, TrendingUp } from "lucide-react";

import { IntensityTrendChart } from "@/components/insights/IntensityTrendChart";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { MemoryInsights } from "@/lib/journal-analytics";

interface MemoryTimelineDashboardProps {
  insights: MemoryInsights;
}

function StatTile({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-4">
      <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
        {label}
      </p>
      <p className="mt-2 text-2xl font-semibold tabular-nums text-white">{value}</p>
    </div>
  );
}

export function MemoryTimelineDashboard({ insights }: MemoryTimelineDashboardProps) {
  const topMood = insights.dominantMoods[0];
  const topTheme = insights.recurringThemes[0];

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatTile label="Total entries" value={insights.totalEntries} />
        <StatTile
          label="Dominant mood"
          value={topMood ? topMood.mood : "—"}
        />
        <StatTile
          label="Top theme"
          value={topTheme ? topTheme.theme.slice(0, 18) : "—"}
        />
        <StatTile
          label="This week"
          value={insights.weeklyMentions.reduce((sum, m) => sum + m.count, 0)}
        />
      </div>

      {insights.weeklyMentions.length > 0 ? (
        <Card className="border-violet-400/20 bg-violet-500/5">
          <CardContent className="p-4">
            <p className="text-sm text-zinc-300">
              {insights.weeklyMentions.slice(0, 3).map((mention, index) => (
                <span key={mention.label}>
                  {index > 0 ? " · " : ""}
                  You mentioned{" "}
                  <span className="font-medium text-violet-200">{mention.label}</span>{" "}
                  {mention.count} time{mention.count === 1 ? "" : "s"} this week
                </span>
              ))}
            </p>
          </CardContent>
        </Card>
      ) : null}

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base font-medium text-zinc-300">
            Dominant moods
          </CardTitle>
        </CardHeader>
        <CardContent>
          {insights.dominantMoods.length === 0 ? (
            <p className="text-sm text-zinc-500">No mood data yet.</p>
          ) : (
            <div className="flex flex-wrap gap-2">
              {insights.dominantMoods.map((mood) => (
                <Badge
                  key={mood.mood}
                  variant="secondary"
                  className="capitalize"
                >
                  {mood.mood} · {mood.count} ({mood.share}%)
                </Badge>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base font-medium text-zinc-300">
            Recurring themes
          </CardTitle>
        </CardHeader>
        <CardContent>
          {insights.recurringThemes.length === 0 ? (
            <p className="text-sm text-zinc-500">Themes surface as you record more.</p>
          ) : (
            <ul className="space-y-2">
              {insights.recurringThemes.map((theme) => (
                <li
                  key={theme.theme}
                  className="flex items-center justify-between text-sm"
                >
                  <span className="capitalize text-zinc-300">{theme.theme}</span>
                  <span className="tabular-nums text-zinc-500">{theme.count}×</span>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <TrendingUp className="h-4 w-4 text-zinc-500" />
            <CardTitle className="text-base font-medium text-zinc-300">
              Emotional intensity trend
            </CardTitle>
          </div>
        </CardHeader>
        <CardContent>
          <IntensityTrendChart points={insights.intensityTrend} />
        </CardContent>
      </Card>

      {insights.mostMentionedConcern ? (
        <Card className="border-amber-500/15 bg-amber-500/5">
          <CardHeader className="pb-2">
            <CardTitle className="text-base font-medium text-zinc-300">
              Most mentioned concern
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed text-zinc-300">
              {insights.mostMentionedConcern}
            </p>
          </CardContent>
        </Card>
      ) : null}

      {insights.positiveSignalsOverTime.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base font-medium text-zinc-300">
              Positive signals over time
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {insights.positiveSignalsOverTime.map((point) => (
              <motion.div
                key={`${point.dayKey}-${point.signal.slice(0, 24)}`}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="rounded-xl border border-white/5 bg-white/[0.02] px-3 py-2.5"
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs text-zinc-500">{point.label}</span>
                  <Badge className="capitalize">{point.mood}</Badge>
                </div>
                <p className="mt-1.5 text-sm leading-relaxed text-zinc-400">
                  {point.signal}
                </p>
              </motion.div>
            ))}
          </CardContent>
        </Card>
      ) : null}

      {insights.mostRepeatedPattern ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base font-medium text-zinc-300">
              Repeated pattern
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed text-zinc-400">
              {insights.mostRepeatedPattern}
            </p>
          </CardContent>
        </Card>
      ) : null}

      <Link
        href="/search"
        className="group flex items-center justify-between rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-3 text-sm text-zinc-400 transition-colors hover:border-violet-400/30 hover:text-violet-200"
      >
        Search across your reflections
        <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
      </Link>
    </div>
  );
}
