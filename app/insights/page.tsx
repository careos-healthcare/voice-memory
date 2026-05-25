"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";

import { UpgradeCta } from "@/components/billing/UpgradeCta";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { MemoryTimelineDashboard } from "@/components/insights/MemoryTimelineDashboard";
import { PatternsDetectedSection } from "@/components/insights/PatternsDetectedSection";
import { ShareMemoryCardButton } from "@/components/memory/ShareMemoryCardButton";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildConservativePatterns } from "@/lib/insights/conservative-patterns";
import { analyzeJournalEntries, type MemoryInsights } from "@/lib/journal-analytics";
import { RETENTION_EVENTS, trackRetentionEvent } from "@/lib/local-analytics";
import { APP_SUBTITLE, WEDGE_RESURFACING } from "@/lib/product-copy";

export default function InsightsPage() {
  const [insights, setInsights] = useState<MemoryInsights | null>(null);
  const [patterns, setPatterns] = useState<ReturnType<typeof buildConservativePatterns> | null>(
    null,
  );

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setInsights(analyzeJournalEntries());
      setPatterns(buildConservativePatterns());
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
            Memory timeline
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Your past words on this device — moods, themes, people, and concerns that
            came back in your own voice.
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

          {insights === null || patterns === null ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading your reflections…
              </CardContent>
            </Card>
          ) : !insights.hasData ? (
            <Card className="border-dashed border-white/5">
              <CardContent className="py-16 text-center">
                <p className="text-zinc-400">Not enough yet for a memory timeline.</p>
                <p className="mt-2 text-sm text-zinc-600">
                  Talk naturally a few times. {WEDGE_RESURFACING.pastWordsMatch}
                </p>
                <Button asChild className="mt-6" variant="secondary">
                  <Link href="/">Record today&apos;s reflection</Link>
                </Button>
              </CardContent>
            </Card>
          ) : (
            <>
              <MemoryTimelineDashboard insights={insights} />

              <PatternsDetectedSection
                patterns={patterns.patterns}
                disclaimer={patterns.disclaimer}
              />

              <section className="space-y-3">
                <h2 className="text-sm font-medium uppercase tracking-wider text-zinc-500">
                  Shareable memory cards
                </h2>
                <ShareMemoryCardButton kind="weekly_summary" />
                <ShareMemoryCardButton kind="dominant_theme" />
              </section>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
