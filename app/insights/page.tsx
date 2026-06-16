"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { AnimatedReveal } from "@/components/motion/AnimatedReveal";

import { ReturnThreadsOverview } from "@/components/continuity/ReturnThreadsOverview";
import { UpgradeCta } from "@/components/billing/UpgradeCta";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { ShareMemoryCardButton } from "@/components/memory/ShareMemoryCardButton";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { BlindSpotReviewCta } from "@/components/blind-spots/BlindSpotReviewCta";
import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { Card, CardContent } from "@/components/ui/card";
import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { RETENTION_EVENTS, trackRetentionEvent } from "@/lib/local-analytics";
import { BELIEF_DOMINANCE_ARCHIVE_CHANGE } from "@/lib/product/belief-dominance-copy";
import { APP_SUBTITLE } from "@/lib/product-copy";
import type { ReturnThreadsReport } from "@/types/return-thread";

export default function InsightsPage() {
  const [report, setReport] = useState<ReturnThreadsReport | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setReport(buildReturnThreads(getMemoryEligibleEntries()));
      trackRetentionEvent(RETENTION_EVENTS.insightViewed);
    });
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
        <AnimatedReveal className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-200">
            {BELIEF_DOMINANCE_ARCHIVE_CHANGE}
          </p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-zinc-100">
            Threads in your archive
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-muted">
            {APP_SUBTITLE} — what came back, what changed, and what is still open. Current
            belief lives on Archive.
          </p>
        </AnimatedReveal>

        <div className="mt-6">
          <UpgradeCta
            source="insights"
            feature="weekly_patterns"
            headline="Full-archive memory return"
            description="Pro connects return threads and weekly remembered moments across your whole archive. Export stays available when you need a copy."
            compact
          />
        </div>

        <BlindSpotReviewCta className="mt-8" />

        <div className="mt-8 space-y-10">
          <HabitLoopCard />

          {report === null ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-muted">
                Reading what came back…
              </CardContent>
            </Card>
          ) : !report.hasData ? (
            <AnticipatoryEmptyState />
          ) : (
            <>
              <ReturnThreadsOverview report={report} />

              <section className="space-y-3 border-t border-white/5 pt-8">
                <h2 className="text-sm font-medium uppercase tracking-wider text-muted">
                  Share a moment
                </h2>
                <ShareMemoryCardButton kind="weekly_summary" />
              </section>
            </>
          )}
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
