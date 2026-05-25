"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Calendar, Flame, Mic, TrendingDown, TrendingUp } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  formatLastReflectionLabel,
  getHabitStats,
  type HabitStats,
} from "@/lib/habit-storage";

function ComparisonRow({
  label,
  today,
  yesterday,
}: {
  label: string;
  today: string;
  yesterday: string;
}) {
  return (
    <div className="flex items-center justify-between gap-4 text-sm">
      <span className="text-zinc-500">{label}</span>
      <div className="flex items-center gap-3 tabular-nums">
        <span className="text-white">{today}</span>
        <span className="text-zinc-600">vs</span>
        <span className="text-zinc-400">{yesterday}</span>
      </div>
    </div>
  );
}

export function HabitLoopCard({ compact = false }: { compact?: boolean }) {
  const [stats, setStats] = useState<HabitStats | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setStats(getHabitStats());
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!stats) return null;

  const consecutiveDays = stats.consecutiveReflectionDays;
  const intensityDelta =
    stats.today.avgIntensity !== null && stats.yesterday.avgIntensity !== null
      ? stats.today.avgIntensity - stats.yesterday.avgIntensity
      : null;

  const recap = stats.weeklyRecap;

  if (compact && !stats.reflectedToday && recap.entryCount === 0) {
    return (
      <div className="rounded-xl px-1 py-2">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-sm font-normal text-zinc-200">Record when you&apos;re ready</p>
            <p className="mt-2 text-xs leading-relaxed text-zinc-500">
              No schedule required — your pace is yours.
            </p>
          </div>
          <Button asChild size="sm">
            <Link href="/">
              <Mic className="h-4 w-4" />
              Record a reflection
            </Link>
          </Button>
        </div>
      </div>
    );
  }

  if (compact) {
    return (
      <div className="space-y-3 rounded-xl px-1 py-2">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="text-xs tracking-wide text-zinc-600">Your reflection rhythm</p>
            <p className="mt-2 flex items-center gap-2 text-xl font-normal text-zinc-200">
              <Calendar className="h-5 w-5 text-violet-300/80" />
              {formatLastReflectionLabel(stats.lastReflectionDate)}
            </p>
            {consecutiveDays > 0 ? (
              <p className="mt-2 flex items-center gap-1.5 text-sm text-zinc-400">
                <Flame className="h-4 w-4 text-amber-400/80" />
                {consecutiveDays} consecutive reflection day{consecutiveDays === 1 ? "" : "s"}
              </p>
            ) : null}
            <p className="mt-2 text-sm text-zinc-500">
              {recap.entryCount > 0
                ? `${recap.entryCount} reflection${recap.entryCount === 1 ? "" : "s"} this week`
                : "Return whenever it helps."}
            </p>
          </div>
          {!stats.reflectedToday ? (
            <Button asChild size="sm" className="shrink-0">
              <Link href="/">
                <Mic className="h-4 w-4" />
                Record today&apos;s reflection
              </Link>
            </Button>
          ) : (
            <span className="rounded-full bg-emerald-500/10 px-3 py-1 text-xs text-emerald-300/90">
              Reflected today
            </span>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className={compact ? "space-y-3" : "space-y-4"}>
      <Card className="border-violet-400/20 bg-gradient-to-br from-violet-500/10 via-transparent to-transparent">
        <CardHeader className="pb-2">
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
                Reflection rhythm
              </p>
              <CardTitle className="mt-2 flex items-center gap-2 text-2xl">
                <Calendar className="h-6 w-6 text-violet-300" />
                {formatLastReflectionLabel(stats.lastReflectionDate)}
              </CardTitle>
              {consecutiveDays > 0 ? (
                <p className="mt-2 flex items-center gap-1.5 text-sm text-zinc-300">
                  <Flame className="h-4 w-4 text-amber-400" />
                  {consecutiveDays} consecutive reflection day{consecutiveDays === 1 ? "" : "s"}
                </p>
              ) : (
                <p className="mt-2 text-sm text-zinc-400">
                  Last reflection · {formatLastReflectionLabel(stats.lastReflectionDate)}
                </p>
              )}
            </div>
            {!stats.reflectedToday ? (
              <Button asChild size="sm" className="shrink-0">
                <Link href="/">
                  <Mic className="h-4 w-4" />
                  Record today&apos;s reflection
                </Link>
              </Button>
            ) : (
              <span className="rounded-full border border-emerald-500/30 bg-emerald-500/10 px-3 py-1 text-xs text-emerald-300">
                Reflected today
              </span>
            )}
          </div>
        </CardHeader>
        {!compact ? (
          <CardContent className="space-y-3 border-t border-white/5 pt-4">
            <p className="text-xs font-medium uppercase tracking-wider text-zinc-500">
              Today vs yesterday
            </p>
            <ComparisonRow
              label="Entries"
              today={String(stats.today.entryCount)}
              yesterday={String(stats.yesterday.entryCount)}
            />
            <ComparisonRow
              label="Avg intensity"
              today={
                stats.today.avgIntensity !== null
                  ? `${stats.today.avgIntensity}/10`
                  : "—"
              }
              yesterday={
                stats.yesterday.avgIntensity !== null
                  ? `${stats.yesterday.avgIntensity}/10`
                  : "—"
              }
            />
            {intensityDelta !== null && intensityDelta !== 0 ? (
              <p className="flex items-center gap-1.5 text-xs text-zinc-500">
                {intensityDelta > 0 ? (
                  <TrendingUp className="h-3.5 w-3.5 text-amber-400" />
                ) : (
                  <TrendingDown className="h-3.5 w-3.5 text-emerald-400" />
                )}
                Emotional intensity{" "}
                {intensityDelta > 0 ? "higher" : "lower"} than yesterday
              </p>
            ) : null}
          </CardContent>
        ) : null}
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base">Weekly recap</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-zinc-400">
          {recap.entryCount === 0 ? (
            <p>No reflections this week yet. Your recap appears after your first entry.</p>
          ) : (
            <ul className="space-y-2">
              <li>
                <span className="text-white">{recap.entryCount}</span> reflection
                {recap.entryCount === 1 ? "" : "s"} logged
              </li>
              {recap.dominantMood ? (
                <li>
                  Dominant mood ·{" "}
                  <span className="capitalize text-zinc-200">{recap.dominantMood}</span>
                </li>
              ) : null}
              {recap.topTheme ? (
                <li>
                  Top theme · <span className="text-zinc-200">{recap.topTheme}</span>
                </li>
              ) : null}
              {recap.avgIntensity !== null ? (
                <li>Average intensity · {recap.avgIntensity}/10</li>
              ) : null}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
