"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Trash2 } from "lucide-react";

import { EntryPhotoAttachment } from "@/components/entry/EntryPhotoAttachment";
import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";
import { MotionPage } from "@/components/motion/MotionPage";
import { MotionNoteList } from "@/components/motion/MotionNote";
import {
  ChangeMomentsNotes,
  ContinuationNotes,
  AnimatedMemoryNote,
  FamiliarityNotes,
  FamiliarityResurfacingNotes,
  ResurfacingNotes,
  RevisitationNotes,
  TimeMemoryNotes,
} from "@/components/patterns/MemoryNote";
import { MilestoneNotes } from "@/components/memory/MilestoneNotes";
import { CopyMemoryMomentButton } from "@/components/memory/CopyMemoryMomentButton";
import { RelationshipContinuityNotes } from "@/components/memory/RelationshipContinuityNotes";
import { MarkReflectionButton } from "@/components/memory/ReflectionBookmarkMark";
import { ThreadMentionsSection } from "@/components/memory/ConversationThreadSection";
import { ReflectOnEntryButton } from "@/components/ReflectOnEntryButton";
import { VoicePlayback } from "@/components/VoicePlayback";
import { VoicePlaybackContinuity } from "@/components/VoicePlaybackContinuity";
import { SiteHeader } from "@/components/SiteHeader";
import { EmotionalProofLine } from "@/components/social-proof/EmotionalProofLine";
import { OnboardingTrustLine } from "@/components/social-proof/OnboardingTrustLine";
import { ShareQuietlyButton } from "@/components/sharing/ShareQuietlyButton";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { entryContinuationOpener } from "@/lib/conversation/conversation-continuity";
import {
  buildFollowupPrompt,
  storeFollowupPrompt,
} from "@/lib/conversation/followup-prompts";
import { resolveRevisitVoicePlaybackPair, resolveVoicePlaybackPair, hasRevisitAudioComparison } from "@/lib/conversation/voice-playback-continuity";
import { entryMilestoneNotes } from "@/lib/memory/milestones";
import { entryRelationshipNotes } from "@/lib/memory/relationship-continuity";
import { threadsForEntry } from "@/lib/memory/conversation-threads";
import { recordEntryDwell, recordEntryView } from "@/lib/callback-interaction-signals";
import {
  recordLastOpenedEntry,
  recordThenVsNowSeen,
} from "@/lib/sync/cross-device-continuity";
import { trackDwellForActiveCallback, trackAudioReplayAfterCallback } from "@/lib/retention/pause-moments";
import { entryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { entryFamiliarityNotes } from "@/lib/memory/familiarity";
import { entryFamiliarityResurfacingNotes } from "@/lib/memory/familiarity-resurfacing";
import { entryResurfacingNotes } from "@/lib/memory/resurfacing";
import { entryRevisitationNotes } from "@/lib/memory/revisitation";
import { entryTimeMemoryNotes } from "@/lib/memory/time-memory";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import { buildQuietEntryPresentation } from "@/lib/refinement/quiet-presentation";
import type { QuietEntryPresentation } from "@/lib/refinement/quiet-presentation";
import {
  buildRevisitExperience,
  trackRevisitAudioPlayed,
  trackRevisitFollowupStarted,
  trackRevisitOpened,
  trackRevisitRewardBookmark,
  trackRevisitRewardSeen,
  trackRevisitThenNowSeen,
  type RevisitExperiencePresentation,
} from "@/lib/refinement/revisit-experience";
import { trackFirstSessionAudioReplayed } from "@/lib/marketing/first-session-comprehension";
import {
  buildCopiedMomentQuietShareCard,
  buildRevisitQuietShareCard,
} from "@/lib/sharing/quiet-sharing";
import { PHOTO_EVENTS, trackPhotoEvent } from "@/lib/local-analytics";
import { buildEntrySharedMemoryMoment } from "@/lib/memory/shared-moments";
import { trackFollowupRecordingStarted } from "@/lib/retention/retention-loops";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { isReflectionPending } from "@/lib/pending-reflection";
import { deleteEntry, getEntry, getMemoryEligibleEntries } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { FollowupPrompt } from "@/types/followup-prompt";

function isDuplicateNote(a: MemoryNote, b: MemoryNote | null | undefined): boolean {
  if (!b) return false;
  return a.id === b.id || a.text === b.text;
}

export default function EntryPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { quiet, limits } = useQuietMode();
  const [entry, setEntry] = useState<JournalEntry | undefined>(undefined);
  const [loading, setLoading] = useState(true);
  const [presentation, setPresentation] = useState<QuietEntryPresentation | null>(null);
  const [revisitExperience, setRevisitExperience] =
    useState<RevisitExperiencePresentation | null>(null);
  const [showReopenFollowup, setShowReopenFollowup] = useState(false);
  const [revisitAudioReplayed, setRevisitAudioReplayed] = useState(false);
  const [momentCopied, setMomentCopied] = useState(false);

  useEffect(() => {
    const found = getEntry(params.id);
    setEntry(found ?? undefined);
    setLoading(false);
  }, [params.id]);

  useEffect(() => {
    if (!entry) return;
    recordEntryView(entry.id);
    recordLastOpenedEntry(entry.id);
    const started = Date.now();
    return () => {
      const dwellMs = Date.now() - started;
      recordEntryDwell(entry.id, dwellMs);
      trackDwellForActiveCallback(dwellMs, "entry");
    };
  }, [entry?.id]);

  const allEntries = useMemo(() => getMemoryEligibleEntries(), [entry]);
  const pending = entry ? isReflectionPending(entry) : false;

  useEffect(() => {
    if (!entry || pending) {
      setPresentation(null);
      setRevisitExperience(null);
      return;
    }
    const id = requestAnimationFrame(() => {
      const limitsPayload = {
        changeMoments: limits.changeMoments,
        familiarityResurfacing: limits.familiarityResurfacing,
        resurfacing: limits.resurfacing,
      };
      const revisit = buildRevisitExperience(allEntries, entry.id, limitsPayload);
      setRevisitExperience(revisit);
      if (revisit.isRevisit) {
        setPresentation(null);
        trackRevisitOpened(entry.id, revisit.sources);
      } else {
        setPresentation(
          buildQuietEntryPresentation(allEntries, entry.id, {
            ...limitsPayload,
            familiarity: limits.familiarity,
          }),
        );
      }
    });
    return () => cancelAnimationFrame(id);
  }, [
    entry,
    allEntries,
    pending,
    limits.changeMoments,
    limits.familiarity,
    limits.familiarityResurfacing,
    limits.resurfacing,
  ]);

  useEffect(() => {
    if (!entry?.id || !revisitExperience?.revisitReward) return;
    trackRevisitRewardSeen(entry.id, revisitExperience.revisitReward.id);
  }, [entry?.id, revisitExperience?.revisitReward?.id]);

  useEffect(() => {
    if (!entry?.id || !revisitExperience?.thenVsNow) return;
    trackRevisitThenNowSeen(entry.id, revisitExperience.thenVsNow.id);
    recordThenVsNowSeen({
      noteId: revisitExperience.thenVsNow.id,
      pastEntryId: revisitExperience.thenVsNow.pastEntryId,
      entryId: entry.id,
    });
  }, [entry?.id, revisitExperience?.thenVsNow?.id]);

  useEffect(() => {
    if (!entry?.id || !entry.photo?.photoId || !revisitExperience?.isRevisit) return;
    trackPhotoEvent(PHOTO_EVENTS.entryRevisited, { entryId: entry.id });
  }, [entry?.id, entry?.photo?.photoId, revisitExperience?.isRevisit]);

  useEffect(() => {
    if (!revisitExperience?.isRevisit) {
      setShowReopenFollowup(false);
      return;
    }
    const delay = revisitExperience.followupDelayMs ?? 0;
    if (delay <= 0) {
      setShowReopenFollowup(true);
      return;
    }
    setShowReopenFollowup(false);
    const timer = window.setTimeout(() => setShowReopenFollowup(true), delay);
    return () => window.clearTimeout(timer);
  }, [revisitExperience?.isRevisit, revisitExperience?.followupDelayMs, entry?.id]);

  const notes = useMemo(() => {
    if (!entry || pending) return null;
    return entryMemoryNotes(allEntries, entry.id);
  }, [entry, allEntries, pending]);

  const revisitShareCard = useMemo(() => {
    if (!entry || !revisitExperience?.isRevisit) return null;
    return buildRevisitQuietShareCard(revisitExperience, entry.id);
  }, [entry, revisitExperience]);

  const copiedShareCard = useMemo(() => {
    if (!entry || revisitExperience?.isRevisit) return null;
    const text = buildEntrySharedMemoryMoment(entry, allEntries);
    return buildCopiedMomentQuietShareCard({
      text,
      sourceId: entry.id,
      entryId: entry.id,
    });
  }, [entry, allEntries, revisitExperience?.isRevisit]);

  const continuationOpener = useMemo(() => {
    if (!entry || pending) return null;
    const opener = entryContinuationOpener(allEntries, entry.id);
    if (!opener) return null;
    if (isDuplicateNote(opener, notes?.primaryCallback)) return null;
    if (isDuplicateNote(opener, notes?.secondaryCallback)) return null;
    if (notes?.thenVsNow.some((t) => isDuplicateNote(opener, t))) return null;
    if (isDuplicateNote(opener, notes?.whatChanged)) return null;
    return opener;
  }, [entry, allEntries, notes, pending]);

  const handleDelete = () => {
    if (!entry) return;
    if (
      !window.confirm(
        "Delete this reflection and its audio from this device? This cannot be undone.",
      )
    ) {
      return;
    }
    deleteEntry(entry.id);
    router.push("/journal");
  };

  const resurfacing = useMemo(() => {
    if (!entry || pending) return [];
    const raw = entryResurfacingNotes(allEntries, entry.id, limits.resurfacing);
    const shown = [
      continuationOpener,
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, limits.resurfacing);
  }, [entry, allEntries, notes, continuationOpener, limits.resurfacing]);

  const timeMemory = useMemo(() => {
    if (!entry || pending) return [];
    const raw = entryTimeMemoryNotes(allEntries, entry.id);
    const shown = [
      continuationOpener,
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, 1);
  }, [entry, allEntries, notes, continuationOpener, resurfacing]);

  const revisitation = useMemo(() => {
    if (!entry || pending) return [];
    const raw = entryRevisitationNotes(allEntries, entry.id);
    const shown = [
      continuationOpener,
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
      ...timeMemory,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, 1);
  }, [entry, allEntries, notes, continuationOpener, resurfacing, timeMemory]);

  const changeMoments = useMemo(() => {
    if (!entry || pending) return [];
    const raw = entryChangeMomentsNotes(allEntries, entry.id, limits.changeMoments);
    const shown = [
      continuationOpener,
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
      ...timeMemory,
      ...revisitation,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, limits.changeMoments);
  }, [entry, allEntries, notes, continuationOpener, resurfacing, timeMemory, revisitation, limits.changeMoments]);

  const familiarity = useMemo(() => {
    if (!entry || pending) return [];
    const raw = entryFamiliarityNotes(allEntries, entry.id, limits.familiarity);
    const shown = [
      continuationOpener,
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
      ...timeMemory,
      ...revisitation,
      ...changeMoments,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, limits.familiarity);
  }, [
    entry,
    allEntries,
    notes,
    continuationOpener,
    resurfacing,
    timeMemory,
    revisitation,
    changeMoments,
    limits.familiarity,
  ]);

  const familiarityResurfacing = useMemo(() => {
    if (!entry || pending) return [];
    const raw = entryFamiliarityResurfacingNotes(
      allEntries,
      entry.id,
      limits.familiarityResurfacing,
    );
    const shown = [
      continuationOpener,
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
      ...timeMemory,
      ...revisitation,
      ...changeMoments,
      ...familiarity,
    ].filter(Boolean) as MemoryNote[];
    return raw
      .filter((r) => !shown.some((s) => isDuplicateNote(r, s)))
      .slice(0, limits.familiarityResurfacing);
  }, [
    entry,
    allEntries,
    notes,
    continuationOpener,
    resurfacing,
    timeMemory,
    revisitation,
    changeMoments,
    familiarity,
    limits.familiarityResurfacing,
  ]);

  const whatChangedLine = useMemo(() => {
    if (!notes?.whatChanged) return null;
    const wc = notes.whatChanged;
    if (isDuplicateNote(wc, notes.primaryCallback)) return null;
    if (isDuplicateNote(wc, notes.secondaryCallback)) return null;
    if (notes.thenVsNow.some((t) => isDuplicateNote(wc, t))) return null;
    return wc;
  }, [notes]);

  const followupNotes = useMemo(() => {
    if (!entry || pending) return [];
    return [
      continuationOpener,
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      ...changeMoments,
      ...familiarityResurfacing,
      ...resurfacing,
      ...revisitation,
    ].filter(Boolean) as MemoryNote[];
  }, [
    entry,
    continuationOpener,
    notes,
    changeMoments,
    familiarityResurfacing,
    resurfacing,
    revisitation,
  ]);

  const followupPrompt = useMemo(
    () => buildFollowupPrompt(followupNotes, allEntries, entry?.id),
    [followupNotes, allEntries, entry?.id],
  );

  const activeFollowup = useMemo(() => {
    if (revisitExperience?.isRevisit) {
      if (!showReopenFollowup) return null;
      return revisitExperience.followupPrompt;
    }
    return presentation?.followupPrompt ?? followupPrompt;
  }, [
    revisitExperience?.isRevisit,
    revisitExperience?.followupPrompt,
    showReopenFollowup,
    presentation?.followupPrompt,
    followupPrompt,
  ]);

  const handleContinueFollowup = (prompt: FollowupPrompt) => {
    if (entry && revisitExperience?.isRevisit) {
      trackRevisitFollowupStarted(entry.id, prompt.id);
    }
    if (prompt.noteId) {
      trackFollowupRecordingStarted(prompt.noteId, prompt.id);
    }
    storeFollowupPrompt(prompt);
    router.push("/#recorder");
  };

  const revisitVoicePair = useMemo(() => {
    if (!entry || pending || !revisitExperience?.isRevisit) return null;
    return resolveRevisitVoicePlaybackPair(entry, allEntries, {
      contrast: revisitExperience.thenVsNow,
      reward: revisitExperience.revisitReward,
    });
  }, [entry, allEntries, pending, revisitExperience]);

  const voicePlaybackPair = useMemo(() => {
    if (!entry || pending) return null;
    return resolveVoicePlaybackPair(entry, allEntries, {
      thenVsNow: notes?.thenVsNow ?? [],
      relatedNotes: [
        continuationOpener,
        notes?.primaryCallback,
        notes?.secondaryCallback,
        ...changeMoments,
        ...familiarityResurfacing,
        ...resurfacing,
        ...revisitation,
        ...timeMemory,
      ].filter(Boolean) as MemoryNote[],
    });
  }, [
    entry,
    allEntries,
    notes,
    continuationOpener,
    changeMoments,
    familiarityResurfacing,
    resurfacing,
    revisitation,
    timeMemory,
  ]);

  const entryThreads = useMemo(() => {
    if (!entry || pending) return [];
    return threadsForEntry(allEntries, entry.id, 3);
  }, [entry, allEntries]);

  const relationshipNotes = useMemo(() => {
    if (!entry || pending) return [];
    return entryRelationshipNotes(allEntries, entry.id, 2);
  }, [entry, allEntries, pending]);

  const milestoneNotes = useMemo(() => {
    if (!entry || pending) return [];
    return entryMilestoneNotes(allEntries, entry.id, limits.milestones);
  }, [entry, allEntries, pending, limits.milestones]);

  return (
    <div className="min-h-screen bg-background">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <div className="mt-4 flex items-center justify-between gap-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/journal">
              <ArrowLeft className="h-4 w-4" />
              Reflections
            </Link>
          </Button>
          {!loading && entry ? (
            <Button variant="ghost" size="sm" onClick={handleDelete}>
              <Trash2 className="h-4 w-4" />
              Delete
            </Button>
          ) : null}
        </div>

        {loading ? (
          <div className="mt-8 space-y-8">
            <Skeleton className="h-8 w-48" />
            <Skeleton className="h-32 w-full" />
          </div>
        ) : !entry ? (
          <MotionPage className="mt-16 text-center">
            <p className="text-lg font-normal text-zinc-200">Entry not found</p>
            <Button asChild className="mt-6">
              <Link href="/">Record a new entry</Link>
            </Button>
          </MotionPage>
        ) : (
          <MotionPage className="mt-10 space-y-20">
            {!pending && revisitExperience?.isRevisit ? (
              <section className="space-y-8 border-b border-white/[0.04] pb-10">
                {revisitExperience.revisitReward ? (
                  <p className="text-[22px] font-normal leading-[1.35] tracking-tight text-zinc-50 sm:text-2xl">
                    {revisitExperience.revisitReward.text}
                  </p>
                ) : null}

                {revisitExperience.livingResurfacing ? (
                  <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">
                    {revisitExperience.livingResurfacing.text}
                  </p>
                ) : null}

                {revisitExperience.voiceIdentity ? (
                  <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">
                    {revisitExperience.voiceIdentity.text}
                  </p>
                ) : null}

                {revisitExperience.emotionalChapter ? (
                  <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">
                    {revisitExperience.emotionalChapter.text}
                  </p>
                ) : null}

                {revisitExperience.thenVsNow ? (
                  <div className="space-y-6">
                    {revisitExperience.thenVsNow.pastQuote ? (
                      <blockquote className="space-y-2 border-l border-zinc-700/60 pl-4">
                        <p className="text-[10px] uppercase tracking-wider text-zinc-600">Before</p>
                        <p className="text-base leading-[1.65] text-zinc-400/95">
                          &ldquo;{revisitExperience.thenVsNow.pastQuote}&rdquo;
                        </p>
                        {revisitExperience.thenVsNow.pastDateLabel ? (
                          <p className="text-xs text-zinc-600">
                            {revisitExperience.thenVsNow.pastDateLabel}
                          </p>
                        ) : null}
                      </blockquote>
                    ) : null}
                    {revisitExperience.thenVsNow.currentQuote ? (
                      <blockquote className="space-y-2 border-l border-zinc-500/40 pl-4">
                        <p className="text-[10px] uppercase tracking-wider text-zinc-500">Now</p>
                        <p className="text-base leading-[1.65] text-zinc-200/95">
                          &ldquo;{revisitExperience.thenVsNow.currentQuote}&rdquo;
                        </p>
                        {revisitExperience.thenVsNow.currentDateLabel ? (
                          <p className="text-xs text-zinc-600">
                            {revisitExperience.thenVsNow.currentDateLabel}
                          </p>
                        ) : null}
                      </blockquote>
                    ) : null}
                  </div>
                ) : null}

                {hasRevisitAudioComparison(revisitVoicePair) && revisitVoicePair ? (
                  <VoicePlaybackContinuity
                    pair={revisitVoicePair}
                    onAudioPlayed={(clip) => {
                      if (entry) {
                        trackRevisitAudioPlayed(entry.id, clip);
                        trackFirstSessionAudioReplayed(entry.id, clip);
                        setRevisitAudioReplayed(true);
                      }
                      trackAudioReplayAfterCallback(
                        revisitExperience?.thenVsNow?.id ??
                          revisitExperience?.revisitReward?.id,
                        clip,
                        "entry",
                      );
                    }}
                  />
                ) : null}

                <FollowupPromptInline
                  prompt={activeFollowup}
                  onContinue={handleContinueFollowup}
                />

                <OnboardingTrustLine
                  isRevisit={revisitExperience.isRevisit}
                  hasRevisitReward={Boolean(revisitExperience.revisitReward)}
                  hasThenVsNow={Boolean(revisitExperience.thenVsNow)}
                  reopenPayoffScore={revisitExperience.reopenPayoffScore?.total ?? null}
                  audioReplayed={revisitAudioReplayed}
                />

                <div className="pt-2">
                  <EmotionalProofLine surface="entry_revisit" />
                </div>

                <ShareQuietlyButton card={revisitShareCard} />
              </section>
            ) : null}

            <header className="space-y-4">
              <h1 className="text-xl font-normal tracking-tight text-zinc-100 sm:text-2xl">
                {formatEntryDate(entry.createdAt)}
              </h1>
              <MarkReflectionButton
                entryId={entry.id}
                onMarked={
                  revisitExperience?.isRevisit
                    ? (type) => trackRevisitRewardBookmark(entry.id, type)
                    : undefined
                }
              />
              {!pending && !revisitExperience?.isRevisit ? (
                <div className="flex flex-wrap items-center gap-2">
                  <CopyMemoryMomentButton
                    source="entry"
                    entry={entry}
                    allEntries={allEntries}
                    onCopied={() => setMomentCopied(true)}
                  />
                  <ShareQuietlyButton
                    card={copiedShareCard}
                    copiedBefore={momentCopied}
                  />
                </div>
              ) : null}
            </header>

            {entry.audioId || entry.transcript ? (
              <section className="space-y-8">
                {entry.audioId &&
                !(revisitExperience?.isRevisit && hasRevisitAudioComparison(revisitVoicePair)) ? (
                  <VoicePlayback
                    entryId={entry.id}
                    audioId={entry.audioId}
                    durationSeconds={entry.durationSeconds}
                  />
                ) : null}
                {entry.transcript ? (
                  <p className="text-sm leading-[1.75] text-zinc-400/90">{entry.transcript}</p>
                ) : null}
              </section>
            ) : null}

            <EntryPhotoAttachment
              entryId={entry.id}
              photo={entry.photo}
              onPhotoChange={(photo) => setEntry((current) => (current ? { ...current, photo } : current))}
            />

            {pending ? (
              <ReflectOnEntryButton
                entryId={entry.id}
                onComplete={(updated) => setEntry(updated)}
              />
            ) : revisitExperience?.isRevisit ? null : quiet ? (
                  <>
                    {presentation?.continuation ? (
                      <ContinuationNotes notes={[presentation.continuation]} max={1} />
                    ) : null}

                    <ThreadMentionsSection threads={entryThreads} />

                    {presentation?.primaryMoment ? (
                      <MotionNoteList className="space-y-20">
                        <AnimatedMemoryNote note={presentation.primaryMoment} index={0} />
                      </MotionNoteList>
                    ) : null}

                    <FollowupPromptInline
                      prompt={activeFollowup}
                      onContinue={handleContinueFollowup}
                    />

                    {voicePlaybackPair && presentation?.primaryMoment ? (
                      <VoicePlaybackContinuity
                        pair={voicePlaybackPair}
                        onAudioPlayed={(clip) => {
                          trackFirstSessionAudioReplayed(voicePlaybackPair.nowEntry.id, clip);
                          trackAudioReplayAfterCallback(
                            presentation.primaryMoment?.id,
                            clip,
                            "entry",
                          );
                        }}
                      />
                    ) : null}
                  </>
                ) : (
                  <>
                {continuationOpener ? (
                  <ContinuationNotes notes={[continuationOpener]} max={1} />
                ) : null}

                <ThreadMentionsSection threads={entryThreads} />

                <RelationshipContinuityNotes notes={relationshipNotes} max={2} />

                <MilestoneNotes
                  milestones={milestoneNotes}
                  entries={allEntries}
                  max={limits.milestones}
                />

                <MotionNoteList className="space-y-20">
                  {notes?.primaryCallback ? (
                    <AnimatedMemoryNote note={notes.primaryCallback} index={0} />
                  ) : null}

                  {notes?.secondaryCallback &&
                  !isDuplicateNote(notes.secondaryCallback, notes.primaryCallback) ? (
                    <AnimatedMemoryNote note={notes.secondaryCallback} index={1} />
                  ) : null}

                  {notes?.thenVsNow.map((note, index) => (
                    <AnimatedMemoryNote key={note.id} note={note} index={index + 2} />
                  ))}
                </MotionNoteList>

                <div className="space-y-20">
                  <ChangeMomentsNotes notes={changeMoments} max={limits.changeMoments} />
                  <FamiliarityNotes notes={familiarity} max={limits.familiarity} />
                  <FamiliarityResurfacingNotes
                    notes={familiarityResurfacing}
                    max={limits.familiarityResurfacing}
                  />
                  <ResurfacingNotes notes={resurfacing} max={limits.resurfacing} />
                  <RevisitationNotes notes={revisitation} max={1} />
                  <TimeMemoryNotes notes={timeMemory} max={1} />
                </div>

                <FollowupPromptInline
                  prompt={activeFollowup}
                  onContinue={handleContinueFollowup}
                />

                {voicePlaybackPair ? (
                  <VoicePlaybackContinuity pair={voicePlaybackPair} />
                ) : null}

                {whatChangedLine ? (
                  <p className="text-sm leading-[1.75] text-zinc-500/90">{whatChangedLine.text}</p>
                ) : null}
                  </>
                )}
          </MotionPage>
        )}
      </div>
    </div>
  );
}
