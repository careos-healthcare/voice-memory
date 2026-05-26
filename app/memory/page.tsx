"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Brain } from "lucide-react";

import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { MilestoneNotes } from "@/components/memory/MilestoneNotes";
import { ContinuityDepthNote } from "@/components/memory/ContinuityDepthNote";
import { ArchiveGravityNote } from "@/components/memory/ArchiveGravityNote";
import { EmotionalChapterNote } from "@/components/memory/EmotionalChapterNote";
import { LivingResurfacingNote } from "@/components/memory/LivingResurfacingNote";
import { RevisitRhythmNote } from "@/components/memory/RevisitRhythmNote";
import { ArchiveValueMoments } from "@/components/retention/ArchiveValueMoments";
import { OpenLoopsSection } from "@/components/open-loops/OpenLoopsSection";
import { GentleReturnPrompt } from "@/components/retention/GentleReturnPrompt";
import { SlowRealizationNote } from "@/components/memory/SlowRealizationNote";
import { ArchiveLandmarkNote } from "@/components/memory/ArchiveLandmarkNote";
import { RelationshipContinuityNotes } from "@/components/memory/RelationshipContinuityNotes";
import { ThreadMentionsSection } from "@/components/memory/ConversationThreadSection";
import { EntityMemorySection } from "@/components/memory/EntityMemorySection";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { MemoryNotesOverview, ChangeMomentsNotes, FamiliarityNotes, FamiliarityResurfacingNotes, RhythmNotes, ResurfacingNotes, RevisitationNotes } from "@/components/patterns/MemoryNote";
import { SiteHeader } from "@/components/SiteHeader";
import { ONBOARDING_MEMORY } from "@/lib/onboarding/onboarding-copy";
import { PRODUCT_WEDGE_LINE } from "@/lib/product-copy";
import { Button } from "@/components/ui/button";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { buildEntityMemory, type EntityMemorySnapshot } from "@/lib/entity-memory";
import { memoryContinuityDepthIndicator } from "@/lib/memory/continuity-depth";
import { memoryArchiveGravityMoment } from "@/lib/refinement/archive-gravity";
import { memoryEmotionalChapterMoment } from "@/lib/memory/emotional-chapters";
import { memoryLivingResurfacingMoment } from "@/lib/memory/living-resurfacing";
import {
  memoryRevisitRhythmMoment,
  revisitRhythmKindFromNote,
  trackRevisitRhythmSeen,
} from "@/lib/refinement/revisit-rhythm";
import { pickPrimaryArchiveLandmark } from "@/lib/archive/archive-landmarks";
import { memorySlowRealizationNote } from "@/lib/memory/slow-realizations";
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
import type { JournalEntry } from "@/types/journal";
import type { ContinuityDepthIndicator } from "@/types/continuity-depth";

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
  const [threadHighlights, setThreadHighlights] = useState<ConversationThread[]>([]);
  const [relationshipNotes, setRelationshipNotes] = useState<RelationshipContinuityNote[]>([]);
  const [milestones, setMilestones] = useState<EmotionalMilestone[]>([]);
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [continuityDepth, setContinuityDepth] = useState<ContinuityDepthIndicator | null>(null);
  const [archiveGravity, setArchiveGravity] = useState<MemoryNote | null>(null);
  const [livingResurfacing, setLivingResurfacing] = useState<MemoryNote | null>(null);
  const [emotionalChapter, setEmotionalChapter] = useState<MemoryNote | null>(null);
  const [revisitRhythm, setRevisitRhythm] = useState<MemoryNote | null>(null);
  const [slowRealization, setSlowRealization] = useState<MemoryNote | null>(null);
  const [archiveLandmark, setArchiveLandmark] = useState<MemoryNote | null>(null);

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
      setThreadHighlights(memoryThreadHighlights(entries, 4));
      setRelationshipNotes(memoryRelationshipNotes(entries, 4));
      setMilestones(memoryMilestoneNotes(entries, limits.milestones));
      setEntries(entries);
      setContinuityDepth(memoryContinuityDepthIndicator(entries));
      setArchiveGravity(memoryArchiveGravityMoment(entries));
      setLivingResurfacing(memoryLivingResurfacingMoment(entries));
      setEmotionalChapter(memoryEmotionalChapterMoment(entries));
      setRevisitRhythm(memoryRevisitRhythmMoment(entries));
      setSlowRealization(memorySlowRealizationNote(entries));
      setArchiveLandmark(pickPrimaryArchiveLandmark(entries));
    });
    return () => cancelAnimationFrame(id);
  }, [
    limits.notes,
    limits.resurfacing,
    limits.changeMoments,
    limits.familiarity,
    limits.rhythm,
    limits.familiarityResurfacing,
    limits.milestones,
  ]);

  useEffect(() => {
    if (!revisitRhythm) return;
    const kind = revisitRhythmKindFromNote(revisitRhythm);
    if (!kind) return;
    trackRevisitRhythmSeen(revisitRhythm.id, kind);
  }, [revisitRhythm?.id]);

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
    () => buildFollowupPrompt(followupNotes, entries),
    [followupNotes, entries],
  );

  const handleContinueFollowup = (prompt: FollowupPrompt) => {
    storeFollowupPrompt(prompt);
    router.push("/#recorder");
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <MotionPageTitle title={ONBOARDING_MEMORY.title} />
        <p className="mt-3 text-sm leading-relaxed text-zinc-500">{PRODUCT_WEDGE_LINE}</p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-600">{ONBOARDING_MEMORY.wedge}</p>

        <div className="mt-16 space-y-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">{ONBOARDING_MEMORY.loading}</p>
          ) : !snapshot.hasData ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <Brain className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">{ONBOARDING_MEMORY.empty}</p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/">Start recording</Link>
                </Button>
              </div>
            </>
          ) : (
            <>
              <GentleReturnPrompt />
              <OpenLoopsSection />
              <ArchiveValueMoments />

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

              <ArchiveGravityNote note={archiveGravity} />
              <LivingResurfacingNote note={livingResurfacing} />
              <EmotionalChapterNote note={emotionalChapter} />
              <RevisitRhythmNote note={revisitRhythm} />
              <SlowRealizationNote note={slowRealization} />
              <ArchiveLandmarkNote note={archiveLandmark} />
              <ContinuityDepthNote indicator={continuityDepth} />

              <ChangeMomentsNotes notes={changeMoments} max={limits.changeMoments} />
              <FamiliarityNotes notes={familiarity} max={limits.familiarity} />
              <FamiliarityResurfacingNotes
                notes={familiarityResurfacing}
                max={limits.familiarityResurfacing}
              />
              <RhythmNotes notes={rhythm} max={limits.rhythm} />
              <ResurfacingNotes notes={resurfacing} max={limits.resurfacing} />
              <RevisitationNotes notes={revisitation} max={1} />
              <ThreadMentionsSection threads={threadHighlights} />
              <RelationshipContinuityNotes notes={relationshipNotes} max={4} />
              <MilestoneNotes
                milestones={milestones}
                entries={entries}
                max={limits.milestones}
              />
              <FollowupPromptInline
                prompt={followupPrompt}
                onContinue={handleContinueFollowup}
              />

              {snapshot.totalEntities > 0 ? (
                <div className="space-y-20 pt-4">
                  <EntityMemorySection entities={snapshot.people} />
                  <EntityMemorySection entities={snapshot.concerns} />
                  <EntityMemorySection entities={snapshot.topics} />
                </div>
              ) : null}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
