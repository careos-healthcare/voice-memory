"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Brain } from "lucide-react";

import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { MilestoneNotes } from "@/components/memory/MilestoneNotes";
import { RelationshipContinuityNotes } from "@/components/memory/RelationshipContinuityNotes";
import { ThreadMentionsSection } from "@/components/memory/ConversationThreadSection";
import { EntityMemorySection } from "@/components/memory/EntityMemorySection";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { ArchiveGrowthNotes, MemoryNotesOverview, ChangeMomentsNotes, FamiliarityNotes, FamiliarityResurfacingNotes, RhythmNotes, ResurfacingNotes, RevisitationNotes } from "@/components/patterns/MemoryNote";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { buildEntityMemory, type EntityMemorySnapshot } from "@/lib/entity-memory";
import { memoryArchiveGrowthNotes } from "@/lib/memory/archive-growth";
import { memoryMilestoneNotes } from "@/lib/memory/milestones";
import { memoryRelationshipNotes } from "@/lib/memory/relationship-continuity";
import { memoryThreadHighlights } from "@/lib/memory/conversation-threads";
import { memoryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { memoryFamiliarityNotes } from "@/lib/memory/familiarity";
import { memoryFamiliarityResurfacingNotes } from "@/lib/memory/familiarity-resurfacing";
import { memoryRhythmNotes } from "@/lib/memory/rhythm-memory";
import { memoryResurfacingNotes } from "@/lib/memory/resurfacing";
import { memoryRevisitationNotes } from "@/lib/memory/revisitation";
import {
  buildFollowupPrompt,
  storeFollowupPrompt,
} from "@/lib/conversation/followup-prompts";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { EmotionalMilestone } from "@/types/emotional-milestone";
import type { RelationshipContinuityNote } from "@/types/relationship-continuity";
import type { ConversationThread } from "@/types/conversation-thread";
import type { MemoryNotesReport } from "@/types/memory-note";
import type { MemoryNote } from "@/types/memory-note";
import type { FollowupPrompt } from "@/types/followup-prompt";

export default function MemoryPage() {
  const router = useRouter();
  const { limits } = useQuietMode();
  const [snapshot, setSnapshot] = useState<EntityMemorySnapshot | null>(null);
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);
  const [revisitation, setRevisitation] = useState<MemoryNote[]>([]);
  const [changeMoments, setChangeMoments] = useState<MemoryNote[]>([]);
  const [familiarity, setFamiliarity] = useState<MemoryNote[]>([]);
  const [rhythm, setRhythm] = useState<MemoryNote[]>([]);
  const [familiarityResurfacing, setFamiliarityResurfacing] = useState<MemoryNote[]>([]);
  const [archiveGrowth, setArchiveGrowth] = useState<MemoryNote[]>([]);
  const [threadHighlights, setThreadHighlights] = useState<ConversationThread[]>([]);
  const [relationshipNotes, setRelationshipNotes] = useState<RelationshipContinuityNote[]>([]);
  const [milestones, setMilestones] = useState<EmotionalMilestone[]>([]);

  useEffect(() => {
    trackLaunchEvent(LAUNCH_EVENTS.memoryPageOpened);
    const id = requestAnimationFrame(() => {
      const entries = getMemoryEligibleEntries();
      const resurfacingNotes = memoryResurfacingNotes(entries, limits.resurfacing);
      const revisitationNotes = memoryRevisitationNotes(entries);
      const changeMomentNotes = memoryChangeMomentsNotes(entries, limits.changeMoments);
      const familiarityResurfacingNotes = memoryFamiliarityResurfacingNotes(
        entries,
        limits.familiarityResurfacing,
      );
      setSnapshot(buildEntityMemory());
      setNotes(buildMemoryNotesReport(entries, { context: "memory", maxTotal: limits.notes }));
      setResurfacing(resurfacingNotes);
      setChangeMoments(changeMomentNotes);
      setFamiliarity(memoryFamiliarityNotes(entries, limits.familiarity));
      setRhythm(memoryRhythmNotes(entries, limits.rhythm));
      setFamiliarityResurfacing(familiarityResurfacingNotes);
      setRevisitation(revisitationNotes);
      const meaningfulTiming =
        resurfacingNotes.length > 0 ||
        revisitationNotes.length > 0 ||
        changeMomentNotes.length > 0 ||
        familiarityResurfacingNotes.length > 0;
      setArchiveGrowth(
        memoryArchiveGrowthNotes(entries, meaningfulTiming).slice(0, limits.archiveGrowth),
      );
      setThreadHighlights(memoryThreadHighlights(entries, 4));
      setRelationshipNotes(memoryRelationshipNotes(entries, 4));
      setMilestones(memoryMilestoneNotes(entries, limits.milestones));
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

  const loading = snapshot === null;

  const followupNotes = useMemo(
    () =>
      [
        ...(notes?.changed ?? []),
        ...(notes?.returned ?? []),
        ...changeMoments,
        ...familiarityResurfacing,
        ...resurfacing,
        ...revisitation,
      ] satisfies MemoryNote[],
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

        <MotionPageTitle eyebrow="Memory" title="Your archive" />

        <div className="mt-20 space-y-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">Reading your archive…</p>
          ) : !snapshot.hasData ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <Brain className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">No memory yet</p>
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
              <ArchiveGrowthNotes notes={archiveGrowth} max={limits.archiveGrowth} />
              <ThreadMentionsSection
                threads={threadHighlights}
                subtitle="Recurring topics that span more than one reflection."
              />
              <RelationshipContinuityNotes
                notes={relationshipNotes}
                max={4}
                subtitle="How people and places appear differently across your archive."
              />
              <MilestoneNotes
                milestones={milestones}
                max={limits.milestones}
                subtitle="Rare moments when something shifted — shown sparingly."
              />
              <FollowupPromptInline
                prompt={followupPrompt}
                onContinue={handleContinueFollowup}
              />

              {snapshot.totalEntities > 0 ? (
                <div className="space-y-20 pt-4">
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
