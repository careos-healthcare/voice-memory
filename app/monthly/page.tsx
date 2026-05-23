"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { CalendarDays } from "lucide-react";

import { MemoryNotesOverview, ChangeMomentsNotes, ResurfacingNotes, RevisitationNotes, TimeMemoryNotes } from "@/components/patterns/MemoryNote";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { monthlyChangeMomentsNotes } from "@/lib/memory/change-moments";
import { monthlyResurfacingNotes } from "@/lib/memory/resurfacing";
import { monthlyRevisitationNotes } from "@/lib/memory/revisitation";
import { monthlyTimeMemoryNotes } from "@/lib/memory/time-memory";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { getAllEntries } from "@/lib/storage";
import type { MemoryNote } from "@/types/memory-note";
import type { MemoryNotesReport } from "@/types/memory-note";

export default function MonthlyPage() {
  const { limits } = useQuietMode();
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);
  const [timeMemory, setTimeMemory] = useState<MemoryNote[]>([]);
  const [revisitation, setRevisitation] = useState<MemoryNote[]>([]);
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);
  const [changeMoments, setChangeMoments] = useState<MemoryNote[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setNotes(buildMemoryNotesReport(entries, { context: "monthly", maxTotal: limits.notes }));
      setTimeMemory(monthlyTimeMemoryNotes(entries));
      setRevisitation(monthlyRevisitationNotes(entries));
      setResurfacing(monthlyResurfacingNotes(entries, limits.resurfacing));
      setChangeMoments(monthlyChangeMomentsNotes(entries, limits.changeMoments));
    });
    return () => cancelAnimationFrame(id);
  }, [limits.notes, limits.resurfacing, limits.changeMoments]);

  const loading = notes === null;
  const hasTimeMemory = timeMemory.length > 0;
  const hasRevisitation = revisitation.length > 0;
  const hasResurfacing = resurfacing.length > 0;
  const hasChangeMoments = changeMoments.length > 0;
  const hasNotes = notes?.hasData ?? false;

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
          ) : !hasNotes && !hasTimeMemory && !hasRevisitation && !hasResurfacing && !hasChangeMoments ? (
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
            <>
              <ChangeMomentsNotes notes={changeMoments} max={limits.changeMoments} />
              <ResurfacingNotes notes={resurfacing} max={limits.resurfacing} />
              <RevisitationNotes notes={revisitation} max={2} />
              <TimeMemoryNotes notes={timeMemory} max={2} />
              {hasNotes ? (
                <MemoryNotesOverview
                  changed={notes!.changed}
                  faded={notes!.faded}
                  returned={notes!.returned}
                  landmarks={notes!.landmarks}
                  maxPerSection={2}
                  maxLandmarks={4}
                />
              ) : null}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
