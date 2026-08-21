"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Calendar, Mic } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
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
      <span className="text-muted">{label}</span>
      <div className="flex items-center gap-3 tabular-nums">
        <span className="text-white">{today}</span>
        <span className="text-muted">vs</span>
        <span className="text-zinc-300">{yesterday}</span>
      </div>
    </div>
  );
}

export function HabitLoopCard({
  compact = false,
  suppressRecordCta = false,
}: {
  compact?: boolean;
  /** Hide habit-loop record links when the homepage primary recorder CTA owns the surface. */
  suppressRecordCta?: boolean;
}) {
  const [stats, setStats] = useState<HabitStats | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setStats(getHabitStats());
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!stats) return null;

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
          {!suppressRecordCta ? (
            <Button asChild size="sm">
              <Link href="/">
                <Mic className="h-4 w-4" />
                Record a reflection
              </Link>
            </Button>
          ) : null}
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
            <p className="mt-2 text-sm text-zinc-500">
              {recap.entryCount > 0
                ? `${recap.entryCount} reflection${recap.entryCount === 1 ? "" : "s"} this week`
                : "Return whenever it helps."}
            </p>
          </div>
          {stats.reflectedToday ? (
            <span className="rounded-full bg-emerald-500/10 px-3 py-1 text-xs text-emerald-300/90">
              Reflected today
            </span>
          ) : suppressRecordCta ? null : (
            <Button asChild size="sm" className="shrink-0">
              <Link href="/">
                <Mic className="h-4 w-4" />
                Record when ready
              </Link>
            </Button>
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
              <p className="mt-2 text-sm text-zinc-400">
                {stats.weeklyRecap.entryCount > 0
                  ? `${stats.weeklyRecap.entryCount} reflection${stats.weeklyRecap.entryCount === 1 ? "" : "s"} this week`
                  : `Last reflection · ${formatLastReflectionLabel(stats.lastReflectionDate)}`}
              </p>
            </div>
            {stats.reflectedToday ? (
              <span className="rounded-full border border-emerald-500/30 bg-emerald-500/10 px-3 py-1 text-xs text-emerald-300">
                Reflected today
              </span>
            ) : suppressRecordCta ? null : (
              <Button asChild size="sm" className="shrink-0">
                <Link href="/">
                  <Mic className="h-4 w-4" />
                  Record when ready
                </Link>
              </Button>
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
          </CardContent>
        ) : null}
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base">Weekly recap</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-zinc-400">
          {recap.entryCount === 0 ? (
            <p>
              After 1–3 real reflections, a weekly recap can name what repeated in your words.
            </p>
          ) : (
            <ul className="space-y-2">
              <li>
                <span className="text-white">{recap.entryCount}</span> reflection
                {recap.entryCount === 1 ? "" : "s"} logged
              </li>
              {recap.topTheme ? (
                <li>
                  Topic you named most ·{" "}
                  <span className="text-zinc-200">{recap.topTheme}</span>
                </li>
              ) : null}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
