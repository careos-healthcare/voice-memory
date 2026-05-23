"use client";

import Link from "next/link";
import { ArrowLeftRight, Shield } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { Contradiction } from "@/lib/patterns/contradictions";

interface ContradictionContinuityCardProps {
  contradictions: Contradiction[];
  title?: string;
  subtitle?: string;
  emptyLabel?: string;
  maxItems?: number;
  highlightEntryId?: string;
  className?: string;
}

function confidenceLabel(score: number): string {
  if (score >= 70) return "Strong pattern";
  if (score >= 50) return "Moderate pattern";
  return "Possible pattern";
}

export function ContradictionContinuityCard({
  contradictions,
  title = "Contradictions & continuity",
  subtitle = "Tension between your words over time — not a diagnosis",
  emptyLabel = "No contradictions detected yet. They appear as patterns accumulate across entries.",
  maxItems = 4,
  highlightEntryId,
  className,
}: ContradictionContinuityCardProps) {
  const items = contradictions.slice(0, maxItems);

  if (items.length === 0) {
    return (
      <Card className={`border-dashed border-white/10 ${className ?? ""}`}>
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <ArrowLeftRight className="h-4 w-4 text-amber-300" />
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
    <Card className={`border-amber-500/20 bg-amber-950/10 ${className ?? ""}`}>
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <ArrowLeftRight className="h-4 w-4 text-amber-300" />
          <CardTitle className="text-base">{title}</CardTitle>
        </div>
        {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex items-start gap-2 rounded-xl border border-white/5 bg-white/[0.02] px-3 py-2 text-xs text-zinc-500">
          <Shield className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          Reflective mirror only — these note language patterns, not clinical labels.
        </div>

        {items.map((item) => (
          <div
            key={item.id}
            className="rounded-xl border border-white/10 bg-black/20 p-4"
          >
            <div className="flex flex-wrap items-start justify-between gap-2">
              <p className="text-sm font-medium text-white">{item.title}</p>
              <Badge variant="secondary" className="shrink-0 text-[10px]">
                {confidenceLabel(item.confidence)} · {item.confidence}%
              </Badge>
            </div>
            <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.explanation}</p>
            <div className="mt-3 space-y-2">
              {item.evidence.map((ev) => (
                <div
                  key={`${item.id}-${ev.entryId}`}
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
                      {ev.dateLabel}
                    </Link>
                    {ev.mood ? (
                      <span className="text-[10px] capitalize text-zinc-600">{ev.mood}</span>
                    ) : null}
                  </div>
                  <p className="mt-1 text-xs italic leading-relaxed text-zinc-400">
                    &ldquo;{ev.phrase}&rdquo;
                  </p>
                </div>
              ))}
            </div>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
