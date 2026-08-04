"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight } from "lucide-react";

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

/** Words-first continuity overview — no mood badges or intensity charts. */
export function MemoryTimelineDashboard({ insights }: MemoryTimelineDashboardProps) {
  const topTheme = insights.recurringThemes[0];

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <StatTile label="Moments saved" value={insights.totalEntries} />
        <StatTile
          label="Words that returned"
          value={insights.mostRepeatedPattern ? "Yes" : "—"}
        />
        <StatTile
          label="Topic mentioned this week"
          value={
            insights.weeklyMentions.length > 0
              ? insights.weeklyMentions[0]!.count
              : "—"
          }
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
            Topics in your words
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
                  <span className="text-zinc-300">{theme.theme}</span>
                  <span className="tabular-nums text-zinc-500">{theme.count}×</span>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      {insights.mostRepeatedPattern ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base font-medium text-zinc-300">
              Phrase that returned
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed text-zinc-400">
              {insights.mostRepeatedPattern}
            </p>
          </CardContent>
        </Card>
      ) : topTheme ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base font-medium text-zinc-300">
              Often in your words lately
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed text-zinc-400">
              {topTheme.theme} — {topTheme.count} moments
            </p>
          </CardContent>
        </Card>
      ) : null}

      {insights.mostMentionedConcern ? (
        <Card className="border-white/10 bg-white/[0.02]">
          <CardHeader className="pb-2">
            <CardTitle className="text-base font-medium text-zinc-300">
              In your own words recently
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed text-zinc-300">
              {insights.mostMentionedConcern}
            </p>
          </CardContent>
        </Card>
      ) : null}

      <Link
        href="/search"
        className="group flex items-center justify-between rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-3 text-sm text-zinc-400 transition-colors hover:border-violet-400/30 hover:text-violet-200"
      >
        Search across your saved words
        <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
      </Link>
    </div>
  );
}
