"use client";

import Link from "next/link";
import { MessageSquareQuote } from "lucide-react";

import { Badge } from "@/archived-components/_archived/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { PhraseMemoryRecord } from "@/lib/patterns/phrase-memory";

interface PhraseMemoryCardProps {
  phrases: PhraseMemoryRecord[];
  title?: string;
  subtitle?: string;
  emptyLabel?: string;
  maxItems?: number;
  highlightEntryId?: string;
  showOccurrences?: boolean;
  hideWhenEmpty?: boolean;
  className?: string;
}

function categoryLabel(category: PhraseMemoryRecord["category"]): string {
  switch (category) {
    case "linguistic_habit":
      return "Linguistic habit";
    case "metaphor":
      return "Metaphor";
    case "self_label":
      return "Self-label";
    case "framing":
      return "Framing";
  }
}

export function PhraseMemoryCard({
  phrases,
  title = "Repeated language",
  subtitle = "Phrases you return to across entries",
  emptyLabel = "Repeated phrases appear as you accumulate voice reflections.",
  maxItems = 6,
  highlightEntryId,
  showOccurrences = true,
  hideWhenEmpty = false,
  className,
}: PhraseMemoryCardProps) {
  const items = phrases.slice(0, maxItems);

  if (items.length === 0) {
    if (hideWhenEmpty) return null;
    return (
      <Card className={`border-dashed border-white/10 ${className ?? ""}`}>
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <MessageSquareQuote className="h-4 w-4 text-emerald-300" />
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
    <Card className={`border-emerald-500/20 bg-emerald-950/10 ${className ?? ""}`}>
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <MessageSquareQuote className="h-4 w-4 text-emerald-300" />
          <CardTitle className="text-base">{title}</CardTitle>
        </div>
        {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
      </CardHeader>
      <CardContent className="space-y-4">
        {items.map((item) => (
          <div
            key={`${item.category}-${item.phrase}`}
            className="rounded-xl border border-white/10 bg-black/20 p-4"
          >
            <div className="flex flex-wrap items-start justify-between gap-2">
              <p className="text-sm font-medium text-white">&ldquo;{item.phrase}&rdquo;</p>
              <Badge variant="secondary" className="shrink-0 text-[10px]">
                {categoryLabel(item.category)}
              </Badge>
            </div>
            <p className="mt-2 text-xs text-zinc-500">
              {item.count} use{item.count === 1 ? "" : "s"} · {item.entryIds.length} entr
              {item.entryIds.length === 1 ? "y" : "ies"} · first{" "}
              {item.firstSeenLabel} · last {item.lastSeenLabel}
            </p>
            {item.dominantMood ? (
              <p className="mt-1 text-xs text-zinc-600">
                Often around{" "}
                <span className="capitalize text-zinc-400">{item.dominantMood}</span>
                {item.avgIntensity > 0 ? ` · avg intensity ${item.avgIntensity}/10` : null}
              </p>
            ) : null}

            {showOccurrences && item.occurrences.length > 0 ? (
              <div className="mt-3 space-y-2">
                {item.occurrences.map((occ) => (
                  <div
                    key={`${item.phrase}-${occ.entryId}-${occ.dateKey}`}
                    className={`rounded-lg border px-3 py-2 ${
                      highlightEntryId === occ.entryId
                        ? "border-violet-400/30 bg-violet-500/10"
                        : "border-white/5 bg-white/[0.02]"
                    }`}
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <Link
                        href={`/entry/${occ.entryId}`}
                        className="text-xs text-violet-300 hover:text-violet-200"
                      >
                        {occ.dateLabel}
                      </Link>
                      <span className="text-[10px] capitalize text-zinc-600">
                        {occ.mood} · {occ.intensity}/10
                      </span>
                    </div>
                    <p className="mt-1 text-xs italic leading-relaxed text-zinc-400">
                      {occ.snippet}
                    </p>
                  </div>
                ))}
              </div>
            ) : null}
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
