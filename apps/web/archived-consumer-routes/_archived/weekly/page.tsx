"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { AnimatedReveal } from "@/components/motion/AnimatedReveal";
import { CalendarRange } from "lucide-react";

import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { MemoryNotesOverview } from "@/components/patterns/MemoryNote";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { Card, CardContent } from "@/components/ui/card";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { analyzeWeeklyIntelligence } from "@/lib/weekly-intelligence";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { MemoryNotesReport } from "@/types/memory-note";

export default function WeeklyPage() {
  const { limits } = useQuietMode();
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);
  const [weekLabel, setWeekLabel] = useState<string | null>(null);
  const [hasData, setHasData] = useState(false);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getMemoryEligibleEntries();
      const report = analyzeWeeklyIntelligence();
      setWeekLabel(report.weekRangeLabel);
      setHasData(report.hasData);
      setNotes(buildMemoryNotesReport(entries, { context: "weekly", maxTotal: limits.notes }));
    });
    return () => cancelAnimationFrame(id);
  }, [limits.notes]);

  const loading = notes === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
        <AnimatedReveal>
          <p className="text-xs uppercase tracking-[0.2em] text-muted">Weekly</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">This week</h1>
          {weekLabel ? <p className="mt-2 text-sm text-muted">{weekLabel}</p> : null}
        </AnimatedReveal>

        <div className="mt-16 space-y-16">
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-muted">
                Reading your archive…
              </CardContent>
            </Card>
          ) : !hasData ? (
            <AnticipatoryEmptyState
              icon={<CalendarRange className="h-6 w-6 text-violet-300" />}
            />
          ) : notes?.hasData ? (
            <MemoryNotesOverview
              changed={notes.changed}
              faded={notes.faded}
              returned={notes.returned}
              landmarks={notes.landmarks}
              maxPerSection={2}
              maxLandmarks={4}
            />
          ) : null}
        </div>

        {hasData ? (
          <div className="mt-16">
            <Link href="/roundups/week" className="text-sm text-muted transition-colors hover:text-zinc-200">
              Weekly roundup →
            </Link>
          </div>
        ) : null}
        </PrimaryMain>
      </div>
    </div>
  );
}
