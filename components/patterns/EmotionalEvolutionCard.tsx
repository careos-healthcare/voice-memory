"use client";

import Link from "next/link";
import { LineChart, TrendingUp } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  type EvolutionInsight,
  type WeeklyEvolutionComparison,
} from "@/lib/patterns/emotional-evolution";

interface EmotionalEvolutionCardProps {
  insights: EvolutionInsight[];
  title?: string;
  subtitle?: string;
  emptyLabel?: string;
  maxItems?: number;
  weekComparison?: WeeklyEvolutionComparison | null;
  showWeekComparison?: boolean;
  hideWhenEmpty?: boolean;
  className?: string;
}

function windowLabel(window: EvolutionInsight["window"]): string {
  switch (window) {
    case "7d":
      return "7 days";
    case "30d":
      return "30 days";
    case "all":
      return "All time";
  }
}

export function EmotionalEvolutionCard({
  insights,
  title = "Emotional evolution",
  subtitle = "How mood and intensity move across your entries",
  emptyLabel = "Emotional patterns emerge as you add voice reflections.",
  maxItems = 8,
  weekComparison = null,
  showWeekComparison = false,
  hideWhenEmpty = false,
  className,
}: EmotionalEvolutionCardProps) {
  const items = insights.slice(0, maxItems);
  const hasWeekLines = showWeekComparison && weekComparison && weekComparison.lines.length > 0;

  if (items.length === 0 && !hasWeekLines) {
    if (hideWhenEmpty) return null;
    return (
      <Card className={`border-dashed border-white/10 ${className ?? ""}`}>
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <LineChart className="h-4 w-4 text-sky-300" />
            <CardTitle className="text-base">{title}</CardTitle>
          </div>
          {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
        </CardHeader>
        <CardContent>
          <p className="text-sm text-zinc-500">{emptyLabel}</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={`border-sky-500/20 bg-sky-950/10 ${className ?? ""}`}>
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <LineChart className="h-4 w-4 text-sky-300" />
          <CardTitle className="text-base">{title}</CardTitle>
        </div>
        {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
      </CardHeader>
      <CardContent className="space-y-4">
        {hasWeekLines ? (
          <div className="rounded-xl border border-sky-500/20 bg-sky-500/5 p-4">
            <div className="flex items-center gap-2 text-xs uppercase tracking-wider text-sky-300/80">
              <TrendingUp className="h-3.5 w-3.5" />
              This week vs last week
            </div>
            <ul className="mt-3 space-y-2">
              {weekComparison!.lines.map((line) => (
                <li key={line} className="text-sm leading-relaxed text-zinc-200">
                  {line}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        {items.map((item) => (
          <div
            key={item.id}
            className="rounded-xl border border-white/10 bg-black/20 p-4"
          >
            <div className="flex flex-wrap items-start justify-between gap-2">
              <p className="text-sm font-medium leading-relaxed text-white">{item.line}</p>
              <Badge variant="secondary" className="shrink-0 text-[10px]">
                {windowLabel(item.window)}
              </Badge>
            </div>
            {item.detail ? (
              <p className="mt-2 text-xs leading-relaxed text-zinc-500">{item.detail}</p>
            ) : null}
            {item.entryIds.length > 0 ? (
              <p className="mt-2 text-[10px] text-zinc-600">
                Based on {item.entryIds.length} reflection
                {item.entryIds.length === 1 ? "" : "s"}
                {item.entryIds.length <= 3
                  ? item.entryIds.map((id) => (
                      <Link
                        key={id}
                        href={`/entry/${id}`}
                        className="ml-1 text-violet-400 hover:text-violet-300"
                      >
                        · view
                      </Link>
                    ))
                  : null}
              </p>
            ) : null}
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
