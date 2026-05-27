"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { CalendarRange } from "lucide-react";

import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { MemoryNotesOverview } from "@/components/patterns/MemoryNote";
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

        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Weekly</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">This week</h1>
          {weekLabel ? <p className="mt-2 text-sm text-zinc-600">{weekLabel}</p> : null}
        </motion.div>

        <div className="mt-16 space-y-16">
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
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
            <Link href="/roundups/week" className="text-sm text-zinc-500 transition-colors hover:text-zinc-300">
              Weekly roundup →
            </Link>
          </div>
        ) : null}
      </div>
    </div>
  );
}
