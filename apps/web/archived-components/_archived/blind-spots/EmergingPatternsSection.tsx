"use client";

import { useEffect, useRef } from "react";
import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { BLIND_SPOT_EVENTS, trackBlindSpotEvent } from "@/lib/blind-spots/blind-spot-events";
import { observeFirstValueMoment } from "@/lib/retention/first-value-moments";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import type { EmergingPattern } from "@/types/blind-spot-acceleration";

interface EmergingPatternsSectionProps {
  patterns: EmergingPattern[];
  reflectionCount: number;
  archiveAgeDays: number;
}

export function EmergingPatternsSection({
  patterns,
  reflectionCount,
  archiveAgeDays,
}: EmergingPatternsSectionProps) {
  const tracked = useRef(false);

  useEffect(() => {
    if (patterns.length === 0 || tracked.current) return;
    tracked.current = true;
    trackBlindSpotEvent(BLIND_SPOT_EVENTS.emergingPatternOpened, {
      reflectionCount,
      archiveAgeDays,
      emergingPatternId: patterns[0]?.id,
    });
    observeFirstValueMoment("emerging_pattern_viewed");
  }, [patterns, reflectionCount, archiveAgeDays]);

  if (patterns.length === 0) return null;

  return (
    <section className="space-y-4">
      <div>
        <h2 className="text-sm font-medium text-zinc-300">{BLIND_SPOT_PAGE.emergingTitle}</h2>
        <p className="mt-1 text-xs leading-relaxed text-zinc-600">
          {BLIND_SPOT_PAGE.emergingDisclaimer}
        </p>
      </div>

      <div className="space-y-4">
        {patterns.map((pattern) => (
          <Card key={pattern.id} className="border-dashed border-violet-500/20 bg-violet-950/10">
            <CardHeader className="pb-2">
              <div className="flex flex-wrap items-center gap-2">
                <CardTitle className="text-sm font-medium text-violet-200/90">
                  {pattern.label}
                </CardTitle>
                <span className="rounded-full border border-white/10 px-2 py-0.5 text-[10px] uppercase tracking-wider text-zinc-500">
                  {pattern.confidenceLabel}
                </span>
              </div>
              <p className="mt-2 text-sm leading-relaxed text-zinc-400">{pattern.hypothesis}</p>
              <p className="text-xs text-zinc-600">
                {pattern.matchingReflections} related reflections — hypothesis only
              </p>
            </CardHeader>
            <CardContent className="space-y-3">
              {pattern.evidenceQuotes.map((item) => (
                <div
                  key={`${pattern.id}-${item.entryId}`}
                  className="rounded-lg border border-white/5 bg-black/15 p-3"
                >
                  <p className="text-[11px] uppercase tracking-wider text-zinc-500">
                    {item.dateLabel}
                  </p>
                  <p className="mt-1 text-sm text-zinc-300">“{item.quote}”</p>
                  <Link
                    href={`/entry/${item.entryId}`}
                    className="mt-2 inline-block text-xs text-zinc-500 hover:text-violet-300"
                  >
                    Open reflection
                  </Link>
                </div>
              ))}
            </CardContent>
          </Card>
        ))}
      </div>
    </section>
  );
}
