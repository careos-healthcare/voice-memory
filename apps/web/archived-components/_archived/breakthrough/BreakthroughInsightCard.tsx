"use client";

import { Sparkles } from "lucide-react";

import { BREAKTHROUGH_FEED_COPY } from "@/lib/breakthrough/breakthrough-shift-detector";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";

interface BreakthroughInsightCardProps {
  headline?: string;
  detailLine?: string;
  className?: string;
}

/** High-impact card for significant archive shifts in product feeds. */
export function BreakthroughInsightCard({
  headline,
  detailLine,
  className = "",
}: BreakthroughInsightCardProps) {
  return (
    <Card
      className={`border-amber-400/30 bg-gradient-to-br from-amber-950/40 via-zinc-950/20 to-transparent ${className}`}
      data-testid="breakthrough-insight-card"
    >
      <CardContent className="space-y-2 px-4 py-4">
        <div className="flex items-center gap-2 text-amber-200/90">
          <Sparkles className="h-4 w-4 shrink-0" aria-hidden />
          <p className="text-xs uppercase tracking-[0.16em]">
            {BREAKTHROUGH_FEED_COPY.eyebrow}
          </p>
        </div>
        <p className="text-sm font-medium text-zinc-100">
          {headline ?? BREAKTHROUGH_FEED_COPY.title}
        </p>
        {detailLine ? (
          <p className="text-sm tabular-nums text-amber-100/90">{detailLine}</p>
        ) : null}
        <p className="text-sm leading-relaxed text-zinc-400">
          {BREAKTHROUGH_FEED_COPY.body}
        </p>
      </CardContent>
    </Card>
  );
}
