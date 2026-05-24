"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CalendarRange } from "lucide-react";

import { PrimaryCallbackNote } from "@/components/memory/PrimaryCallbackNote";
import { ArchiveGravityNote } from "@/components/memory/ArchiveGravityNote";
import { EmotionalChapterNote } from "@/components/memory/EmotionalChapterNote";
import { VoiceIdentityNote } from "@/components/memory/VoiceIdentityNote";
import { RevisitEntryLink } from "@/components/navigation/RevisitEntryLink";

import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";

import { MilestoneNotes } from "@/components/memory/MilestoneNotes";
import { BookmarkIndicator } from "@/components/memory/ReflectionBookmarkMark";
import { ThreadMentionsSection } from "@/components/memory/ConversationThreadSection";
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
import { useBookmarkedEntryIds } from "@/lib/hooks/useReflectionBookmark";
import { timelineMilestoneNotes } from "@/lib/memory/milestones";
import { timelineThreadHighlights } from "@/lib/memory/conversation-threads";
import { timelineKnowsMeMoment } from "@/lib/refinement/knows-me-moments";
import { timelineArchiveGravityMoment } from "@/lib/refinement/archive-gravity";
import { timelineEmotionalChapterMoment } from "@/lib/memory/emotional-chapters";
import { timelineVoiceIdentityMoment } from "@/lib/memory/voice-identity";
import { calibratePrimaryNote } from "@/lib/refinement/silence-calibration";
import { orderEntriesForRevisitPrompts } from "@/lib/refinement/revisit-worth";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { getAllEntries, getMemoryEligibleEntries } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { EmotionalMilestone } from "@/types/emotional-milestone";
import type { ConversationThread } from "@/types/conversation-thread";
import type { MemoryNotesReport } from "@/types/memory-note";
import type { MemoryNote } from "@/types/memory-note";
import type { JournalEntry } from "@/types/journal";
import type { FollowupPrompt } from "@/types/followup-prompt";

export default function TimelinePage() {
  const router = useRouter();
  const { limits } = useQuietMode();
  const [knowsMe, setKnowsMe] = useState<MemoryNote | null>(null);
  const [archiveGravity, setArchiveGravity] = useState<MemoryNote | null>(null);
  const [voiceIdentity, setVoiceIdentity] = useState<MemoryNote | null>(null);
  const [emotionalChapter, setEmotionalChapter] = useState<MemoryNote | null>(null);
  const [notes, setNotes] = useState<MemoryNotesReport | null>(null);
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);
  const [timeMemory, setTimeMemory] = useState<MemoryNote[]>([]);
  const [revisitation, setRevisitation] = useState<MemoryNote[]>([]);
  const [changeMoments, setChangeMoments] = useState<MemoryNote[]>([]);
  const [familiarity, setFamiliarity] = useState<MemoryNote[]>([]);
  const [rhythm, setRhythm] = useState<MemoryNote[]>([]);
  const [familiarityResurfacing, setFamiliarityResurfacing] = useState<MemoryNote[]>([]);
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [threadHighlights, setThreadHighlights] = useState<ConversationThread[]>([]);
  const [milestones, setMilestones] = useState<EmotionalMilestone[]>([]);
  const bookmarkedIds = useBookmarkedEntryIds();

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const allEntries = getAllEntries();
      const memoryEntries = getMemoryEligibleEntries();
      setEntries(allEntries);
      setNotes(buildMemoryNotesReport(memoryEntries, { context: "timeline", maxTotal: limits.notes }));
      setResurfacing(archiveResurfacingNotes(memoryEntries, limits.resurfacing));
      setChangeMoments(timelineChangeMomentsNotes(memoryEntries, limits.changeMoments));
      setFamiliarity(timelineFamiliarityNotes(memoryEntries, limits.familiarity));
      setFamiliarityResurfacing(
        timelineFamiliarityResurfacingNotes(memoryEntries, limits.familiarityResurfacing),
      );
      setRhythm(timelineRhythmNotes(memoryEntries, limits.rhythm));
      setTimeMemory(timelineTimeMemoryNotes(memoryEntries));
      setRevisitation(timelineRevisitationNotes(memoryEntries));
      setThreadHighlights(timelineThreadHighlights(memoryEntries, 3));
      setMilestones(timelineMilestoneNotes(memoryEntries, limits.milestones));
      setKnowsMe(
        calibratePrimaryNote(
          [timelineKnowsMeMoment(memoryEntries)].filter(Boolean) as MemoryNote[],
          memoryEntries,
          "timeline",
        ),
      );
      setArchiveGravity(timelineArchiveGravityMoment(memoryEntries));
      setVoiceIdentity(timelineVoiceIdentityMoment(memoryEntries));
      setEmotionalChapter(timelineEmotionalChapterMoment(memoryEntries));
    });
    return () => cancelAnimationFrame(id);
  }, [
    limits.notes,
    limits.resurfacing,
    limits.changeMoments,
    limits.familiarity,
    limits.familiarityResurfacing,
    limits.rhythm,
    limits.milestones,
  ]);

  const loading = notes === null;
  const reflectionEntries = useMemo(() => {
    const eligible = entries.filter((entry) => entry.reflectionPending !== true);
    return orderEntriesForRevisitPrompts(eligible, 12);
  }, [entries]);

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

        <MotionPageTitle title="Over time" />

        <div className="mt-20 space-y-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">One moment…</p>
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
              <PrimaryCallbackNote note={knowsMe} />
              <ArchiveGravityNote note={archiveGravity} />
              <VoiceIdentityNote note={voiceIdentity} />
              <EmotionalChapterNote note={emotionalChapter} />
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

              <ThreadMentionsSection threads={threadHighlights} />

              <MilestoneNotes milestones={milestones} entries={entries} max={limits.milestones} />

              <section className="space-y-6 pt-4">
                <h2 className="text-xs font-normal tracking-wide text-zinc-600">Reflections</h2>
                <ul className="space-y-2">
                  {reflectionEntries.map((entry) => (
                    <li key={entry.id}>
                      <RevisitEntryLink
                        entryId={entry.id}
                        source="timeline"
                        className="flex items-center gap-3 px-1 py-3 text-sm text-zinc-500 transition-colors hover:text-zinc-300"
                      >
                        <span>{formatEntryDate(entry.createdAt)}</span>
                        <BookmarkIndicator
                          entryId={entry.id}
                          bookmarkedIds={bookmarkedIds}
                        />
                      </RevisitEntryLink>
                    </li>
                  ))}
                </ul>
                {entries.filter((entry) => entry.reflectionPending !== true).length > 12 ? (
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
