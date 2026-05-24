"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildSoftEmotionalTimelineReport } from "@/lib/personalization/soft-emotional-timeline";
import type { SoftEmotionalTimelineReport } from "@/types/personalization";

const BAND_CLASS: Record<
  SoftEmotionalTimelineReport["segments"][number]["intensityBand"],
  string
> = {
  quiet: "bg-zinc-600/20",
  steady: "bg-violet-500/15",
  heavy: "bg-zinc-500/25",
  mixed: "bg-zinc-600/15",
};

export default function FeelingsTimelinePage() {
  const [report, setReport] = useState<SoftEmotionalTimelineReport | null>(null);

  useEffect(() => {
    setReport(buildSoftEmotionalTimelineReport());
  }, []);

  return (
    <div className="min-h-screen bg-background">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <header className="mt-6 space-y-3">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Optional view</p>
          <h1 className="text-2xl font-normal tracking-tight text-foreground sm:text-3xl">
            How this has felt over time
          </h1>
          <p className="max-w-xl text-sm leading-relaxed text-zinc-500">
            A quiet read of movement across weeks — not a chart wall, not a score, not a diagnosis.
          </p>
        </header>

        <div className="mt-14 space-y-8">
          {!report ? (
            <p className="text-sm text-zinc-600">One moment…</p>
          ) : report.segments.length === 0 ? (
            <div className="py-16 text-center">
              <p className="text-sm text-zinc-500">Not enough reflections yet for a gentle timeline.</p>
              <Button asChild className="mt-6" variant="secondary">
                <Link href="/">Record a reflection</Link>
              </Button>
            </div>
          ) : (
            <ul className="space-y-6">
              {report.segments.map((segment) => (
                <li
                  key={segment.id}
                  className="rounded-xl border border-white/[0.06] px-4 py-4 sm:px-5"
                >
                  <div className="flex items-start gap-4">
                    <div
                      className={`mt-1 h-10 w-1 shrink-0 rounded-full ${BAND_CLASS[segment.intensityBand]}`}
                      aria-hidden
                    />
                    <div className="space-y-1">
                      <p className="text-sm text-zinc-500">{segment.periodLabel}</p>
                      <p className="text-base font-normal leading-relaxed text-zinc-300">
                        {segment.feelingLine}
                      </p>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="mt-12 flex flex-wrap gap-3 text-sm">
          <Link href="/timeline" className="text-violet-300 hover:text-violet-200">
            Full timeline →
          </Link>
          <Link href="/settings" className="text-zinc-500 hover:text-zinc-300">
            Personalization →
          </Link>
        </div>
      </div>
    </div>
  );
}
