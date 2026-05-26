"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";

import { ReturnThreadsOverview } from "@/components/continuity/ReturnThreadsOverview";
import { UpgradeCta } from "@/components/billing/UpgradeCta";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { ShareMemoryCardButton } from "@/components/memory/ShareMemoryCardButton";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { RETENTION_EVENTS, trackRetentionEvent } from "@/lib/local-analytics";
import { APP_SUBTITLE, WEDGE_RESURFACING } from "@/lib/product-copy";
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

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            {APP_SUBTITLE}
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            What keeps returning
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Unfinished conversations in your own words — what came back, what changed,
            and what is still open.
          </p>
        </motion.div>

        <div className="mt-6">
          <UpgradeCta
            source="insights"
            feature="weekly_patterns"
            headline="Search your full reflection history"
            description="Pro unlocks full history search, export reports, and weekly resurfacing. Free searches recent reflections on this device."
            compact
          />
        </div>

        <div className="mt-8 space-y-10">
          <HabitLoopCard />

          {report === null ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading what came back…
              </CardContent>
            </Card>
          ) : !report.hasData ? (
            <Card className="border-dashed border-white/5">
              <CardContent className="py-16 text-center">
                <p className="text-zinc-400">Not enough yet to see what returns.</p>
                <p className="mt-2 text-sm text-zinc-600">
                  Talk naturally a few times. {WEDGE_RESURFACING.pastWordsMatch}
                </p>
                <Button asChild className="mt-6" variant="secondary">
                  <Link href="/">Record a reflection</Link>
                </Button>
              </CardContent>
            </Card>
          ) : (
            <>
              <ReturnThreadsOverview report={report} />

              <section className="space-y-3 border-t border-white/5 pt-8">
                <h2 className="text-sm font-medium uppercase tracking-wider text-zinc-500">
                  Share a moment
                </h2>
                <ShareMemoryCardButton kind="weekly_summary" />
              </section>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
