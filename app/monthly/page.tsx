"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CalendarDays } from "lucide-react";

import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";

import { MilestoneNotes } from "@/components/memory/MilestoneNotes";
import { ArchiveGrowthNotes, MemoryNotesOverview, ChangeMomentsNotes, FamiliarityNotes, FamiliarityResurfacingNotes, RhythmNotes, ResurfacingNotes, RevisitationNotes, TimeMemoryNotes } from "@/components/patterns/MemoryNote";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { monthlyMilestoneNotes } from "@/lib/memory/milestones";
import { monthlyArchiveGrowthNotes } from "@/lib/memory/archive-growth";
import { monthlyChangeMomentsNotes } from "@/lib/memory/change-moments";
import { monthlyFamiliarityNotes } from "@/lib/memory/familiarity";
import { monthlyFamiliarityResurfacingNotes } from "@/lib/memory/familiarity-resurfacing";
import { monthlyRhythmNotes } from "@/lib/memory/rhythm-memory";
import { monthlyResurfacingNotes } from "@/lib/memory/resurfacing";
import { monthlyRevisitationNotes } from "@/lib/memory/revisitation";
import { monthlyTimeMemoryNotes } from "@/lib/memory/time-memory";
import {
  buildFollowupPrompt,
  storeFollowupPrompt,
} from "@/lib/conversation/followup-prompts";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { EmotionalMilestone } from "@/types/emotional-milestone";
import type { MemoryNote } from "@/types/memory-note";
import type { MemoryNotesReport } from "@/types/memory-note";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";

export default function MonthlyPage() {
  const router = useRouter();
  const { limits } = useQuietMode();
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);
  const [timeMemory, setTimeMemory] = useState<MemoryNote[]>([]);
  const [revisitation, setRevisitation] = useState<MemoryNote[]>([]);
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);
  const [changeMoments, setChangeMoments] = useState<MemoryNote[]>([]);
  const [familiarity, setFamiliarity] = useState<MemoryNote[]>([]);
  const [rhythm, setRhythm] = useState<MemoryNote[]>([]);
  const [familiarityResurfacing, setFamiliarityResurfacing] = useState<MemoryNote[]>([]);
  const [archiveGrowth, setArchiveGrowth] = useState<MemoryNote[]>([]);
  const [milestones, setMilestones] = useState<EmotionalMilestone[]>([]);
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getMemoryEligibleEntries();
      const resurfacingNotes = monthlyResurfacingNotes(entries, limits.resurfacing);
      const revisitationNotes = monthlyRevisitationNotes(entries);
      const changeMomentNotes = monthlyChangeMomentsNotes(entries, limits.changeMoments);
      const familiarityResurfacingNotes = monthlyFamiliarityResurfacingNotes(
        entries,
        limits.familiarityResurfacing,
      );
      setNotes(buildMemoryNotesReport(entries, { context: "monthly", maxTotal: limits.notes }));
      setTimeMemory(monthlyTimeMemoryNotes(entries));
      setRevisitation(revisitationNotes);
      setResurfacing(resurfacingNotes);
      setChangeMoments(changeMomentNotes);
      setFamiliarity(monthlyFamiliarityNotes(entries, limits.familiarity));
      setRhythm(monthlyRhythmNotes(entries, limits.rhythm));
      setFamiliarityResurfacing(familiarityResurfacingNotes);
      const meaningfulTiming =
        resurfacingNotes.length > 0 ||
        revisitationNotes.length > 0 ||
        changeMomentNotes.length > 0 ||
        familiarityResurfacingNotes.length > 0;
      setArchiveGrowth(
        monthlyArchiveGrowthNotes(entries, meaningfulTiming).slice(0, limits.archiveGrowth),
      );
      setMilestones(monthlyMilestoneNotes(entries, limits.milestones));
      setEntries(entries);
    });
    return () => cancelAnimationFrame(id);
  }, [
    limits.notes,
    limits.resurfacing,
    limits.changeMoments,
    limits.familiarity,
    limits.rhythm,
    limits.familiarityResurfacing,
    limits.archiveGrowth,
    limits.milestones,
  ]);

  const loading = notes === null;
  const hasTimeMemory = timeMemory.length > 0;
  const hasRevisitation = revisitation.length > 0;
  const hasResurfacing = resurfacing.length > 0;
  const hasChangeMoments = changeMoments.length > 0;
  const hasFamiliarity = familiarity.length > 0;
  const hasRhythm = rhythm.length > 0;
  const hasFamiliarityResurfacing = familiarityResurfacing.length > 0;
  const hasArchiveGrowth = archiveGrowth.length > 0;
  const hasNotes = notes?.hasData ?? false;

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

        <MotionPageTitle eyebrow="Monthly" title="This month" />

        <div className="mt-20 space-y-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">Reading your archive…</p>
          ) : !hasNotes && !hasTimeMemory && !hasRevisitation && !hasResurfacing && !hasChangeMoments && !hasFamiliarity && !hasRhythm && !hasFamiliarityResurfacing && !hasArchiveGrowth ? (
            <div className="px-2 py-16 text-center">
              <CalendarDays className="mx-auto h-7 w-7 text-zinc-600/80" />
              <p className="mt-5 text-base font-normal text-zinc-400">Not enough yet</p>
              <p className="mt-3 text-sm leading-relaxed text-zinc-600">
                A few more reflections and this page will remember what shifted.
              </p>
              <Button asChild className="mt-8" variant="secondary">
                <Link href="/">Record a reflection</Link>
              </Button>
            </div>
          ) : (
            <>
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
              <ArchiveGrowthNotes notes={archiveGrowth} max={limits.archiveGrowth} />
              <MilestoneNotes milestones={milestones} entries={entries} max={limits.milestones} />
              <FollowupPromptInline
                prompt={followupPrompt}
                onContinue={handleContinueFollowup}
              />
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
