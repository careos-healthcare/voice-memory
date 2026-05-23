"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";

import { MemoryNotesOverview } from "@/components/patterns/MemoryNote";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { MemoryNotesReport } from "@/types/memory-note";

export default function InsightsPage() {
  const { limits } = useQuietMode();
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setNotes(buildMemoryNotesReport(getMemoryEligibleEntries(), { context: "memory", maxTotal: limits.notes }));
    });
    return () => cancelAnimationFrame(id);
  }, [limits.notes]);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-4">
          <h1 className="text-3xl font-semibold text-white">Over time</h1>
        </motion.div>

        <div className="mt-16 space-y-16">
          {notes === null ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">Reading…</CardContent>
            </Card>
          ) : !notes.hasData ? (
            <Card className="border-dashed border-white/5">
              <CardContent className="py-16 text-center">
                <p className="text-zinc-400">Not enough yet.</p>
                <Button asChild className="mt-6" variant="secondary">
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
