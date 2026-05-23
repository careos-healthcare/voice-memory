"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { CalendarRange } from "lucide-react";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { MemoryNotesOverview, ChangeMomentsNotes, FamiliarityNotes, RhythmNotes, ResurfacingNotes, RevisitationNotes, TimeMemoryNotes } from "@/components/patterns/MemoryNote";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { timelineChangeMomentsNotes } from "@/lib/memory/change-moments";
import { timelineFamiliarityNotes } from "@/lib/memory/familiarity";
import { timelineRhythmNotes } from "@/lib/memory/rhythm-memory";
import { archiveResurfacingNotes } from "@/lib/memory/resurfacing";
import { timelineRevisitationNotes } from "@/lib/memory/revisitation";
import { timelineTimeMemoryNotes } from "@/lib/memory/time-memory";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { getAllEntries } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { MemoryNotesReport } from "@/types/memory-note";
import type { MemoryNote } from "@/types/memory-note";
import type { JournalEntry } from "@/types/journal";

export default function TimelinePage() {
  const { limits } = useQuietMode();
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);
  const [timeMemory, setTimeMemory] = useState<MemoryNote[]>([]);
  const [revisitation, setRevisitation] = useState<MemoryNote[]>([]);
  const [changeMoments, setChangeMoments] = useState<MemoryNote[]>([]);
  const [familiarity, setFamiliarity] = useState<MemoryNote[]>([]);
  const [rhythm, setRhythm] = useState<MemoryNote[]>([]);
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const all = getAllEntries();
      setEntries(all);
      setNotes(buildMemoryNotesReport(all, { context: "timeline", maxTotal: limits.notes }));
      setResurfacing(archiveResurfacingNotes(all, limits.resurfacing));
      setChangeMoments(timelineChangeMomentsNotes(all, limits.changeMoments));
      setFamiliarity(timelineFamiliarityNotes(all, limits.familiarity));
      setRhythm(timelineRhythmNotes(all, limits.rhythm));
      setTimeMemory(timelineTimeMemoryNotes(all));
      setRevisitation(timelineRevisitationNotes(all));
    });
    return () => cancelAnimationFrame(id);
  }, [limits.notes, limits.resurfacing, limits.changeMoments, limits.familiarity, limits.rhythm]);

  const loading = notes === null;
  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Timeline</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">Over time</h1>
        </motion.div>

        <div className="mt-16 space-y-16">
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading your archive…
              </CardContent>
            </Card>
          ) : entries.length === 0 ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <Card className="border-dashed border-white/5">
                <CardContent className="px-6 py-16 text-center">
                  <CalendarRange className="mx-auto h-8 w-8 text-zinc-600" />
                  <p className="mt-4 text-lg font-medium text-zinc-300">No timeline yet</p>
                  <Button asChild className="mt-8" variant="secondary">
                    <Link href="/">Start recording</Link>
                  </Button>
                </CardContent>
              </Card>
            </>
          ) : (
            <>
              {notes?.hasData ? (
                <MemoryNotesOverview
                  changed={notes.changed}
                  faded={notes.faded}
                  returned={notes.returned}
                  landmarks={notes.landmarks}
                  maxPerSection={2}
                  maxLandmarks={4}
                />
              ) : null}

              <ChangeMomentsNotes notes={changeMoments} max={limits.changeMoments} />
              <FamiliarityNotes notes={familiarity} max={limits.familiarity} />
              <RhythmNotes notes={rhythm} max={limits.rhythm} />
              <ResurfacingNotes notes={resurfacing} max={limits.resurfacing} />
              <RevisitationNotes notes={revisitation} max={2} />
              <TimeMemoryNotes notes={timeMemory} max={2} />

              <section className="space-y-4 border-t border-white/5 pt-12">
                <h2 className="text-sm font-medium text-zinc-500">Reflections</h2>
                <ul className="space-y-1">
                  {sorted.slice(0, 12).map((entry) => (
                    <li key={entry.id}>
                      <Link
                        href={`/entry/${entry.id}`}
                        className="block rounded-xl px-2 py-4 text-sm text-zinc-400 transition-colors hover:bg-white/[0.03] hover:text-zinc-200"
                      >
                        {formatEntryDate(entry.createdAt)}
                      </Link>
                    </li>
                  ))}
                </ul>
                {sorted.length > 12 ? (
                  <Button asChild variant="ghost" size="sm" className="text-zinc-600">
                    <Link href="/journal">All reflections</Link>
                  </Button>
                ) : null}
              </section>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
