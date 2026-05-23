"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { CalendarDays } from "lucide-react";

import { MemoryNotesOverview } from "@/components/patterns/MemoryNote";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { getAllEntries } from "@/lib/storage";
import type { MemoryNotesReport } from "@/types/memory-note";

export default function MonthlyPage() {
  const { limits } = useQuietMode();
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setNotes(buildMemoryNotesReport(entries, { context: "monthly", maxTotal: limits.notes }));
    });
    return () => cancelAnimationFrame(id);
  }, [limits.notes]);

  const loading = notes === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Monthly</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">This month</h1>
        </motion.div>

        <div className="mt-16 space-y-16">
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading your archive…
              </CardContent>
            </Card>
          ) : !notes?.hasData ? (
            <Card className="border-dashed border-white/5">
              <CardContent className="px-6 py-16 text-center">
                <CalendarDays className="mx-auto h-8 w-8 text-zinc-600" />
                <p className="mt-4 text-lg font-medium text-zinc-300">Not enough yet</p>
                <p className="mt-2 text-sm text-zinc-600">
                  A few more reflections and this page will remember what shifted.
                </p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/">Record a reflection</Link>
                </Button>
              </CardContent>
            </Card>
          ) : (
            <MemoryNotesOverview
              changed={notes.changed}
              faded={notes.faded}
              returned={notes.returned}
              landmarks={notes.landmarks}
              maxPerSection={2}
              maxLandmarks={4}
            />
          )}
        </div>
      </div>
    </div>
  );
}
