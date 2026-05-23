"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CalendarRange } from "lucide-react";

import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { MemoryNotesOverview, ChangeMomentsNotes, FamiliarityNotes, FamiliarityResurfacingNotes, RhythmNotes, ResurfacingNotes, RevisitationNotes, TimeMemoryNotes } from "@/components/patterns/MemoryNote";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { timelineChangeMomentsNotes } from "@/lib/memory/change-moments";
import { timelineFamiliarityNotes } from "@/lib/memory/familiarity";
import { timelineFamiliarityResurfacingNotes } from "@/lib/memory/familiarity-resurfacing";
import { timelineRhythmNotes } from "@/lib/memory/rhythm-memory";
import { archiveResurfacingNotes } from "@/lib/memory/resurfacing";
import { timelineRevisitationNotes } from "@/lib/memory/revisitation";
import { timelineTimeMemoryNotes } from "@/lib/memory/time-memory";
import {
  buildFollowupPrompt,
  storeFollowupPrompt,
} from "@/lib/conversation/followup-prompts";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { getAllEntries } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { MemoryNotesReport } from "@/types/memory-note";
import type { MemoryNote } from "@/types/memory-note";
import type { JournalEntry } from "@/types/journal";
import type { FollowupPrompt } from "@/types/followup-prompt";

export default function TimelinePage() {
  const router = useRouter();
  const { limits } = useQuietMode();
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);
  const [timeMemory, setTimeMemory] = useState<MemoryNote[]>([]);
  const [revisitation, setRevisitation] = useState<MemoryNote[]>([]);
  const [changeMoments, setChangeMoments] = useState<MemoryNote[]>([]);
  const [familiarity, setFamiliarity] = useState<MemoryNote[]>([]);
  const [rhythm, setRhythm] = useState<MemoryNote[]>([]);
  const [familiarityResurfacing, setFamiliarityResurfacing] = useState<MemoryNote[]>([]);
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const all = getAllEntries();
      setEntries(all);
      setNotes(buildMemoryNotesReport(all, { context: "timeline", maxTotal: limits.notes }));
      setResurfacing(archiveResurfacingNotes(all, limits.resurfacing));
      setChangeMoments(timelineChangeMomentsNotes(all, limits.changeMoments));
      setFamiliarity(timelineFamiliarityNotes(all, limits.familiarity));
      setFamiliarityResurfacing(
        timelineFamiliarityResurfacingNotes(all, limits.familiarityResurfacing),
      );
      setRhythm(timelineRhythmNotes(all, limits.rhythm));
      setTimeMemory(timelineTimeMemoryNotes(all));
      setRevisitation(timelineRevisitationNotes(all));
    });
    return () => cancelAnimationFrame(id);
  }, [
    limits.notes,
    limits.resurfacing,
    limits.changeMoments,
    limits.familiarity,
    limits.familiarityResurfacing,
    limits.rhythm,
  ]);

  const loading = notes === null;
  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );

  const followupNotes = useMemo(
    () => [
      ...(notes?.changed ?? []),
      ...(notes?.returned ?? []),
      ...changeMoments,
      ...familiarityResurfacing,
      ...resurfacing,
      ...revisitation,
    ],
    [notes, changeMoments, familiarityResurfacing, resurfacing, revisitation],
  );

  const followupPrompt = useMemo(
    () => buildFollowupPrompt(followupNotes),
    [followupNotes],
  );

  const handleContinueFollowup = (prompt: FollowupPrompt) => {
    storeFollowupPrompt(prompt.text);
    router.push("/#recorder");
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <MotionPageTitle eyebrow="Timeline" title="Over time" />

        <div className="mt-20 space-y-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">Reading your archive…</p>
          ) : entries.length === 0 ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <CalendarRange className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">No timeline yet</p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/">Start recording</Link>
                </Button>
              </div>
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
              <FamiliarityResurfacingNotes
                notes={familiarityResurfacing}
                max={limits.familiarityResurfacing}
              />
              <RhythmNotes notes={rhythm} max={limits.rhythm} />
              <ResurfacingNotes notes={resurfacing} max={limits.resurfacing} />
              <RevisitationNotes notes={revisitation} max={1} />
              <TimeMemoryNotes notes={timeMemory} max={2} />

              <FollowupPromptInline
                prompt={followupPrompt}
                onContinue={handleContinueFollowup}
              />

              <section className="space-y-6 pt-4">
                <h2 className="text-xs font-normal tracking-wide text-zinc-600">Reflections</h2>
                <ul className="space-y-2">
                  {sorted.slice(0, 12).map((entry) => (
                    <li key={entry.id}>
                      <Link
                        href={`/entry/${entry.id}`}
                        className="block px-1 py-3 text-sm text-zinc-500 transition-colors hover:text-zinc-300"
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
