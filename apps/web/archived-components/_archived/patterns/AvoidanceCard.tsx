"use client";

import Link from "next/link";
import { EyeOff } from "lucide-react";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { type AvoidanceSignal } from "@/lib/patterns/avoidance";

interface AvoidanceCardProps {
  signals: AvoidanceSignal[];
  title?: string;
  subtitle?: string;
  emptyLabel?: string;
  maxItems?: number;
  highlightEntryId?: string;
  hideWhenEmpty?: boolean;
  className?: string;
}

export function AvoidanceCard({
  signals,
  title = "What stays vague",
  subtitle = "Where you name the feeling but not the thing",
  emptyLabel = "Indirect phrasing appears as you accumulate voice reflections.",
  maxItems = 5,
  highlightEntryId,
  hideWhenEmpty = false,
  className,
}: AvoidanceCardProps) {
  const items = signals.filter((s) => s.confidence >= 50).slice(0, maxItems);

  if (items.length === 0) {
    if (hideWhenEmpty) return null;

    return (
      <Card className={`border-dashed border-white/10 ${className ?? ""}`}>
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <EyeOff className="h-4 w-4 text-zinc-400" />
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
    <Card className={`border-zinc-500/20 bg-zinc-950/20 ${className ?? ""}`}>
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <EyeOff className="h-4 w-4 text-zinc-400" />
          <CardTitle className="text-base">{title}</CardTitle>
        </div>
        {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
      </CardHeader>
      <CardContent className="space-y-4">
        {items.map((item) => (
          <div
            key={item.id}
            className="rounded-xl border border-white/10 bg-black/20 p-4"
          >
            <p className="text-sm font-medium text-white">{item.title}</p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.explanation}</p>
            <div className="mt-3 space-y-2">
              {item.evidence.map((ev) => (
                <div
                  key={`${item.id}-${ev.entryId}-${ev.phrase.slice(0, 24)}`}
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
                  </div>
                  <p className="mt-1 text-xs italic leading-relaxed text-zinc-400">
                    {ev.phrase}
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
