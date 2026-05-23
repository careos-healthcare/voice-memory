"use client";

import Link from "next/link";
import { Sparkles, Shield } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { insightConfidenceLabel } from "@/lib/patterns/evidence-priority";
import {
  type PatternInsight,
  typeLabel,
} from "@/lib/patterns/pattern-engine";

interface PatternInsightCardProps {
  insights: PatternInsight[];
  title?: string;
  subtitle?: string;
  emptyLabel?: string;
  maxItems?: number;
  highlightEntryId?: string;
  hideWhenEmpty?: boolean;
  showScores?: boolean;
  className?: string;
}

export function PatternInsightCard({
  insights,
  title = "Pattern insights",
  subtitle = "Ranked by specificity, recurrence, and cross-entry evidence",
  emptyLabel = "Pattern insights appear as you accumulate voice reflections.",
  maxItems = 8,
  highlightEntryId,
  hideWhenEmpty = false,
  showScores = false,
  className,
}: PatternInsightCardProps) {
  const items = insights.slice(0, maxItems);

  if (items.length === 0) {
    if (hideWhenEmpty) return null;

    return (
      <Card className={`border-dashed border-white/10 ${className ?? ""}`}>
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <Sparkles className="h-4 w-4 text-violet-300" />
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
    <Card className={`border-violet-500/20 bg-violet-950/10 ${className ?? ""}`}>
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <Sparkles className="h-4 w-4 text-violet-300" />
          <CardTitle className="text-base">{title}</CardTitle>
        </div>
        {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex items-start gap-2 rounded-xl border border-white/5 bg-white/[0.02] px-3 py-2 text-xs text-zinc-500">
          <Shield className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          Pattern-first mirror — not therapy, not a diagnosis. Ranked from your words only.
        </div>

        {items.map((item, index) => (
          <div
            key={item.id}
            className="rounded-xl border border-white/10 bg-black/20 p-4"
          >
            <div className="flex flex-wrap items-start justify-between gap-2">
              <div className="flex items-start gap-2">
                <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-violet-500/20 text-[10px] font-medium text-violet-300">
                  {index + 1}
                </span>
                <p className="text-sm font-medium leading-relaxed text-white">{item.title}</p>
              </div>
              <div className="flex shrink-0 flex-wrap gap-1">
                <Badge variant="secondary" className="text-[10px]">
                  {typeLabel(item.type)}
                </Badge>
                <Badge variant="secondary" className="text-[10px]">
                  {insightConfidenceLabel(item.scores.total)}
                </Badge>
                {showScores ? (
                  <Badge variant="secondary" className="text-[10px]">
                    {item.scores.total}/100
                  </Badge>
                ) : null}
              </div>
            </div>

            <p className="mt-2 text-xs text-zinc-500">
              {item.entryIds.length} entr{item.entryIds.length === 1 ? "y" : "ies"} ·
              recurrence signal {item.scores.recurrenceCount}%
            </p>

            <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.detail}</p>

            {item.evidence.length > 0 ? (
              <div className="mt-3 space-y-2">
                <p className="text-[10px] uppercase tracking-wider text-zinc-600">
                  Exact phrase evidence
                </p>
                {item.evidence.slice(0, 3).map((ev) => (
                  <div
                    key={`${item.id}-${ev.entryId}-${ev.phrase.slice(0, 20)}`}
                    className={`rounded-lg border px-3 py-2 ${
                      highlightEntryId === ev.entryId
                        ? "border-violet-400/30 bg-violet-500/10"
                        : "border-white/5 bg-white/[0.02]"
                    }`}
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <Link
                        href={`/entry/${ev.entryId}`}
                        className="text-xs text-violet-300 hover:text-violet-200"
                      >
                        {ev.dateLabel ?? "View entry"}
                      </Link>
                      {ev.mood ? (
                        <span className="text-[10px] capitalize text-zinc-600">{ev.mood}</span>
                      ) : null}
                    </div>
                    <p className="mt-1 text-xs italic leading-relaxed text-zinc-400">
                      {ev.phrase}
                    </p>
                  </div>
                ))}
              </div>
            ) : null}

            {item.entryIds.length > 0 ? (
              <div className="mt-3 flex flex-wrap gap-2">
                <span className="text-[10px] text-zinc-600">Related entries:</span>
                {item.entryIds.slice(0, 5).map((id) => (
                  <Link
                    key={`${item.id}-link-${id}`}
                    href={`/entry/${id}`}
                    className={`text-[10px] ${
                      highlightEntryId === id
                        ? "font-medium text-violet-300"
                        : "text-violet-400 hover:text-violet-300"
                    }`}
                  >
                    {highlightEntryId === id ? "This entry" : "View"}
                  </Link>
                ))}
                {item.entryIds.length > 5 ? (
                  <span className="text-[10px] text-zinc-600">
                    +{item.entryIds.length - 5} more
                  </span>
                ) : null}
              </div>
            ) : null}
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
