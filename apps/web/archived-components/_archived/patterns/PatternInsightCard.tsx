"use client";

import Link from "next/link";
import { useState } from "react";

import { Badge } from "@/archived-components/_archived/ui/badge";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
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
  primaryCount?: number;
  highlightEntryId?: string;
  hideWhenEmpty?: boolean;
  showScores?: boolean;
  className?: string;
}

function InsightRow({
  item,
  index,
  highlightEntryId,
  showScores,
}: {
  item: PatternInsight;
  index: number;
  highlightEntryId?: string;
  showScores?: boolean;
}) {
  return (
    <div className="rounded-xl border border-white/5 bg-black/10 p-5">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <p className="text-sm leading-relaxed text-zinc-300">{item.title}</p>
        {showScores ? (
          <Badge variant="secondary" className="shrink-0 text-[10px]">
            {typeLabel(item.type)}
          </Badge>
        ) : null}
      </div>
      <p className="mt-3 text-sm leading-relaxed text-zinc-500">{item.detail}</p>
      {item.evidence.length > 0 ? (
        <div className="mt-4 space-y-2">
          {item.evidence.slice(0, 2).map((ev) => (
            <div
              key={`${item.id}-${ev.entryId}`}
              className={`rounded-lg border px-3 py-2 ${
                highlightEntryId === ev.entryId
                  ? "border-violet-400/20 bg-violet-500/5"
                  : "border-white/5"
              }`}
            >
              <Link
                href={`/entry/${ev.entryId}`}
                className="text-xs text-zinc-500 hover:text-zinc-300"
              >
                {ev.dateLabel ?? "View entry"}
              </Link>
              <p className="mt-1 text-xs italic text-zinc-600">{ev.phrase.slice(0, 120)}</p>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}

export function PatternInsightCard({
  insights,
  title = "Further patterns",
  subtitle,
  emptyLabel = "More patterns appear as your archive grows.",
  maxItems = 8,
  primaryCount = 3,
  highlightEntryId,
  hideWhenEmpty = false,
  showScores = false,
  className,
}: PatternInsightCardProps) {
  const [expanded, setExpanded] = useState(false);
  const primary = insights.slice(0, primaryCount);
  const rest = insights.slice(primaryCount, maxItems);
  const items = expanded ? [...primary, ...rest] : primary;

  if (insights.length === 0) {
    if (hideWhenEmpty) return null;

    return (
      <Card className={`border-dashed border-white/5 ${className ?? ""}`}>
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-400">{title}</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-zinc-600">{emptyLabel}</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={`border-white/5 bg-transparent ${className ?? ""}`}>
      <CardHeader className="pb-4">
        <CardTitle className="text-base font-medium text-zinc-400">{title}</CardTitle>
        {subtitle ? <p className="mt-1 text-xs text-zinc-600">{subtitle}</p> : null}
      </CardHeader>
      <CardContent className="space-y-6">
        {items.map((item, index) => (
          <InsightRow
            key={item.id}
            item={item}
            index={index}
            highlightEntryId={highlightEntryId}
            showScores={showScores}
          />
        ))}
        {!expanded && rest.length > 0 ? (
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="w-full text-zinc-600 hover:text-zinc-400"
            onClick={() => setExpanded(true)}
          >
            See more ({rest.length})
          </Button>
        ) : null}
      </CardContent>
    </Card>
  );
}
