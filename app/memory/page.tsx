"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Brain } from "lucide-react";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { EntityMemorySection } from "@/components/memory/EntityMemorySection";
import { MemoryNotesOverview, ChangeMomentsNotes, FamiliarityNotes, ResurfacingNotes, RevisitationNotes } from "@/components/patterns/MemoryNote";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { buildEntityMemory, type EntityMemorySnapshot } from "@/lib/entity-memory";
import { memoryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { memoryFamiliarityNotes } from "@/lib/memory/familiarity";
import { archiveResurfacingNotes } from "@/lib/memory/resurfacing";
import { memoryRevisitationNotes } from "@/lib/memory/revisitation";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { getAllEntries } from "@/lib/storage";
import type { MemoryNotesReport } from "@/types/memory-note";
import type { MemoryNote } from "@/types/memory-note";

export default function MemoryPage() {
  const { limits } = useQuietMode();
  const [snapshot, setSnapshot] = useState<EntityMemorySnapshot | null>(null);
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);
  const [revisitation, setRevisitation] = useState<MemoryNote[]>([]);
  const [changeMoments, setChangeMoments] = useState<MemoryNote[]>([]);
  const [familiarity, setFamiliarity] = useState<MemoryNote[]>([]);

  useEffect(() => {
    trackLaunchEvent(LAUNCH_EVENTS.memoryPageOpened);
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setSnapshot(buildEntityMemory());
      setNotes(buildMemoryNotesReport(entries, { context: "memory", maxTotal: limits.notes }));
      setResurfacing(archiveResurfacingNotes(entries, limits.resurfacing));
      setChangeMoments(memoryChangeMomentsNotes(entries, limits.changeMoments));
      setFamiliarity(memoryFamiliarityNotes(entries, limits.familiarity));
      setRevisitation(memoryRevisitationNotes(entries));
    });
    return () => cancelAnimationFrame(id);
  }, [limits.notes, limits.resurfacing, limits.changeMoments, limits.familiarity]);

  const loading = snapshot === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Memory</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">Your archive</h1>
        </motion.div>

        <div className="mt-16 space-y-16">
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading your archive…
              </CardContent>
            </Card>
          ) : !snapshot.hasData ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <Card className="border-dashed border-white/5">
                <CardContent className="px-6 py-16 text-center">
                  <Brain className="mx-auto h-8 w-8 text-zinc-600" />
                  <p className="mt-4 text-lg font-medium text-zinc-300">No memory yet</p>
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
              <ResurfacingNotes notes={resurfacing} max={limits.resurfacing} />
              <RevisitationNotes notes={revisitation} max={2} />

              {snapshot.totalEntities > 0 ? (
                <div className="space-y-12 border-t border-white/5 pt-12">
                  <EntityMemorySection
                    title="People"
                    subtitle=""
                    entities={snapshot.people}
                    emptyLabel=""
                  />
                  <EntityMemorySection
                    title="Threads"
                    subtitle=""
                    entities={snapshot.concerns}
                    emptyLabel=""
                  />
                  <EntityMemorySection
                    title="Topics"
                    subtitle=""
                    entities={snapshot.topics}
                    emptyLabel=""
                  />
                </div>
              ) : null}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
