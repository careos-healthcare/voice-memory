"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Trash2 } from "lucide-react";

import { EntryPhotoAttachment } from "@/components/entry/EntryPhotoAttachment";
import { EntryAtmosphereAttachment } from "@/components/entry/EntryAtmosphereAttachment";
import { OpenLoopNextStepPrompt } from "@/components/entry/OpenLoopNextStepPrompt";
import { OpenLoopEntryContinuity } from "@/components/open-loops/OpenLoopEntryContinuity";
import { recordComponentRender } from "@/lib/open-loops/open-loop-performance";
import { enqueueRefreshOpenLoopContinuity } from "@/lib/runtime/deferred-jobs";
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
import { MemoryContinuitySection } from "@/components/memory/MemoryContinuitySection";
import { MarkReflectionButton } from "@/components/memory/ReflectionBookmarkMark";
import { EntryPrimaryCallback } from "@/components/entry/EntryPrimaryCallback";
import { ThreadMentionsSection } from "@/components/memory/ConversationThreadSection";
import { TerritoryMentionsSection } from "@/components/territories/TerritorySections";
import { ReflectOnEntryButton } from "@/components/ReflectOnEntryButton";
import { VoicePlayback } from "@/components/VoicePlayback";
import { VoicePlaybackContinuity } from "@/components/VoicePlaybackContinuity";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { EmotionalProofLine } from "@/components/social-proof/EmotionalProofLine";
import { OnboardingTrustLine } from "@/components/social-proof/OnboardingTrustLine";
import { ShareQuietlyButton } from "@/components/sharing/ShareQuietlyButton";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { entryContinuationOpener } from "@/lib/conversation/conversation-continuity";
import { buildFollowupPrompt } from "@/lib/conversation/followup-prompts";
import {
  buildRecordReturnFromFollowup,
  storeRecordReturnContext,
} from "@/lib/reflection/record-return";
import { consumeAfterSaveContinuityLine } from "@/lib/reflection/after-save-continuity";
import { consumeClarityAfterSaveLine } from "@/lib/clarity/clarity-record";
import { buildClarityResurfacingNote } from "@/lib/clarity/clarity-resurfacing";
import { SortThisOutAloudPrompt } from "@/components/clarity/SortThisOutAloudPrompt";
import { CirclingThoughtsSection } from "@/components/clarity/CirclingThoughtsSection";
import { shouldActivateReflexSilenceFirst } from "@/lib/reflex/open-without-record";
import { readClarityPromptOffer } from "@/lib/runtime/read-model";
import {
  writeEnqueueThoughtPatternExtract,
  writeTrackThoughtPatternResurfaced,
} from "@/lib/runtime/write-actions";
import {
  detectThinkingOutLoudSignals,
  qualifiesForClarityPrompt,
} from "@/lib/clarity/thinking-out-loud-signals";
import type { ClarityPromptOffer } from "@/types/clarity";
import { resolveRevisitVoicePlaybackPair, resolveVoicePlaybackPair, hasRevisitAudioComparison } from "@/lib/conversation/voice-playback-continuity";
import { entryMilestoneNotes } from "@/lib/memory/milestones";
import { entryRelationshipNotes } from "@/lib/memory/relationship-continuity";
import { threadsForEntry } from "@/lib/memory/conversation-threads";
import { territoriesForEntry } from "@/lib/territories/emotional-territories";
import { recordEntryDwell, recordEntryView } from "@/lib/callback-interaction-signals";
import {
  clearAmbientPageContext,
  isHeavyEntry,
  recordAmbientSessionActivity,
  setAmbientPageContext,
} from "@/lib/personalization/ambient-adaptation";
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
import { buildMemoryContinuityReport } from "@/lib/memory/memory-continuity";
import type { QuietEntryPresentation } from "@/lib/refinement/quiet-presentation";
import { resurfacingDeferMs } from "@/lib/performance/lightweight-mode";
import {
  readCachedQuietEntryPresentation,
  readCachedRevisitExperience,
} from "@/lib/runtime/read-model";
import {
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
import { registerPhotoReturnTrigger } from "@/lib/retention/return-triggers";
import { trackAtmosphereRevisited } from "@/lib/atmosphere/atmosphere-observation";
import { buildEntrySharedMemoryMoment } from "@/lib/memory/shared-moments";
import { trackFollowupRecordingStarted } from "@/lib/retention/retention-loops";
import { useFreshEntryQuietMode } from "@/lib/hooks/useFreshEntryQuietMode";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { pickEvidenceBackedEntryMoment } from "@/lib/refinement/entry-quiet-state";
import { FRESH_ENTRY_NO_CALLBACK_LINE } from "@/lib/entry/fresh-entry-copy";
import { scheduleAfterMount } from "@/lib/entry/defer-after-mount";
import {
  EMPTY_REVISIT_EXPERIENCE,
  runEntryPresentationSafe,
} from "@/lib/entry/entry-presentation-runtime";
import {
  isInvalidEntryRouteId,
  normalizeEntryRouteId,
  shouldRunEntryPresentationBuilders,
} from "@/lib/entry/entry-route-guard";
import { isReflectionPending } from "@/lib/pending-reflection";
import { deleteEntry, getEntry, getMemoryEligibleEntries, getMemoryEligibleEntriesVersion } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { FollowupPrompt } from "@/types/followup-prompt";

function isDuplicateNote(a: MemoryNote, b: MemoryNote | null | undefined): boolean {
  if (!b) return false;
  return a.id === b.id || a.text === b.text;
}

export default function EntryPage() {
  recordComponentRender("EntryPage");
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const entryId = normalizeEntryRouteId(params.id);
  const routeInvalid = isInvalidEntryRouteId(entryId);
  const { quiet, limits } = useQuietMode();
  const [entry, setEntry] = useState<JournalEntry | undefined>(undefined);
  const [loading, setLoading] = useState(true);
  const [heavyReady, setHeavyReady] = useState(false);
  const [presentation, setPresentation] = useState<QuietEntryPresentation | null>(null);
  const [revisitExperience, setRevisitExperience] =
    useState<RevisitExperiencePresentation | null>(null);
  const canRunBuilders = shouldRunEntryPresentationBuilders(entryId, entry, { loading });
  const { freshQuiet, expandFreshQuiet } = useFreshEntryQuietMode(
    entry,
    Boolean(revisitExperience?.isRevisit),
    heavyReady,
  );
  const [showReopenFollowup, setShowReopenFollowup] = useState(false);
  const [revisitAudioReplayed, setRevisitAudioReplayed] = useState(false);
  const [momentCopied, setMomentCopied] = useState(false);
  const [reflexSilenceFirst, setReflexSilenceFirst] = useState(false);

  useEffect(() => {
    setReflexSilenceFirst(shouldActivateReflexSilenceFirst());
  }, []);

  useEffect(() => {
    if (routeInvalid) {
      setEntry(undefined);
      setLoading(false);
      return;
    }
    setLoading(true);
    const found = getEntry(entryId);
    setEntry(found ?? undefined);
    setLoading(false);
  }, [entryId, routeInvalid]);

  useEffect(() => {
    if (!entry || routeInvalid) return;
    recordEntryView(entry.id);
    recordLastOpenedEntry(entry.id);
    const started = Date.now();
    return () => {
      const dwellMs = Date.now() - started;
      recordEntryDwell(entry.id, dwellMs);
      recordAmbientSessionActivity(entry.id, dwellMs);
      trackDwellForActiveCallback(dwellMs, "entry");
    };
  }, [entry?.id, routeInvalid]);

  useEffect(() => {
    if (!entry || routeInvalid) {
      clearAmbientPageContext();
      return;
    }
    setAmbientPageContext({
      isRevisit: Boolean(revisitExperience?.isRevisit),
      heavyEntry: isHeavyEntry(entry),
    });
    return () => clearAmbientPageContext();
  }, [entry, revisitExperience?.isRevisit]);

  const allEntries = useMemo(() => {
    if (!heavyReady || !entry) return [];
    return getMemoryEligibleEntries();
  }, [heavyReady, entry?.id, entry?.createdAt]);
  const pending = entry ? isReflectionPending(entry) : false;

  useEffect(() => {
    enqueueRefreshOpenLoopContinuity();
  }, []);
  const needsHeavyMemoryBlocks =
    heavyReady &&
    !pending &&
    !freshQuiet &&
    !quiet &&
    !revisitExperience?.isRevisit;

  useEffect(() => {
    if (!canRunBuilders || !entry) {
      setHeavyReady(false);
      setPresentation(null);
      setRevisitExperience(null);
      return;
    }

    let cancelled = false;
    const limitsPayload = {
      changeMoments: limits.changeMoments,
      familiarityResurfacing: limits.familiarityResurfacing,
      resurfacing: limits.resurfacing,
    };

    const runHeavyPath = () => {
      if (cancelled) return;
      try {
        const pool = getMemoryEligibleEntries();
        const entriesVersion = getMemoryEligibleEntriesVersion();
        const revisit = runEntryPresentationSafe(
          () =>
            readCachedRevisitExperience(pool, entry.id, limitsPayload, entriesVersion),
          EMPTY_REVISIT_EXPERIENCE,
        );
        setRevisitExperience(revisit);
        if (revisit.isRevisit) {
          setPresentation(null);
          queueMicrotask(() => trackRevisitOpened(entry.id, revisit.sources));
        } else {
          setPresentation(
            runEntryPresentationSafe(
              () =>
                readCachedQuietEntryPresentation(
                  pool,
                  entry.id,
                  {
                    ...limitsPayload,
                    familiarity: limits.familiarity,
                  },
                  entriesVersion,
                ),
              null,
            ),
          );
        }
      } catch {
        setPresentation(null);
        setRevisitExperience(EMPTY_REVISIT_EXPERIENCE);
      }
      if (!cancelled) setHeavyReady(true);
    };

    const deferMs = resurfacingDeferMs();
    return scheduleAfterMount(runHeavyPath, {
      delayMs: deferMs,
      timeoutMs: 1500,
    });
  }, [
    canRunBuilders,
    entry?.id,
    limits.changeMoments,
    limits.familiarity,
    limits.familiarityResurfacing,
    limits.resurfacing,
  ]);

  useEffect(() => {
    if (routeInvalid || !entry?.id || !heavyReady || !revisitExperience?.revisitReward) return;
    trackRevisitRewardSeen(entry.id, revisitExperience.revisitReward.id);
  }, [entry?.id, revisitExperience?.revisitReward?.id]);

  useEffect(() => {
    if (routeInvalid || !entry?.id || !heavyReady || !revisitExperience?.thenVsNow) return;
    trackRevisitThenNowSeen(entry.id, revisitExperience.thenVsNow.id);
    recordThenVsNowSeen({
      noteId: revisitExperience.thenVsNow.id,
      pastEntryId: revisitExperience.thenVsNow.pastEntryId,
      entryId: entry.id,
    });
  }, [entry?.id, revisitExperience?.thenVsNow?.id]);

  useEffect(() => {
    if (routeInvalid || !entry?.id || !heavyReady || !entry.photo?.photoId || !revisitExperience?.isRevisit) {
      return;
    }
    trackPhotoEvent(PHOTO_EVENTS.entryRevisited, { entryId: entry.id });
    registerPhotoReturnTrigger(entry.id);
  }, [entry?.id, entry?.photo?.photoId, revisitExperience?.isRevisit]);

  useEffect(() => {
    if (
      routeInvalid ||
      !entry?.id ||
      !heavyReady ||
      !entry.atmosphere?.atmosphereId ||
      !revisitExperience?.isRevisit
    ) {
      return;
    }
    trackAtmosphereRevisited(entry.id);
  }, [entry?.id, entry?.atmosphere?.atmosphereId, revisitExperience?.isRevisit]);

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
    if (!needsHeavyMemoryBlocks || !entry) return null;
    return entryMemoryNotes(allEntries, entry.id);
  }, [needsHeavyMemoryBlocks, entry, allEntries]);

  const revisitShareCard = useMemo(() => {
    if (!heavyReady || !entry || !revisitExperience?.isRevisit) return null;
    return buildRevisitQuietShareCard(revisitExperience, entry.id);
  }, [heavyReady, entry, revisitExperience]);

  const copiedShareCard = useMemo(() => {
    if (!heavyReady || !entry || revisitExperience?.isRevisit) return null;
    const text = buildEntrySharedMemoryMoment(entry, allEntries);
    return buildCopiedMomentQuietShareCard({
      text,
      sourceId: entry.id,
      entryId: entry.id,
    });
  }, [heavyReady, entry, allEntries, revisitExperience?.isRevisit]);

  const continuationOpener = useMemo(() => {
    if (!needsHeavyMemoryBlocks || !entry) return null;
    const opener = entryContinuationOpener(allEntries, entry.id);
    if (!opener) return null;
    if (isDuplicateNote(opener, notes?.primaryCallback)) return null;
    if (isDuplicateNote(opener, notes?.secondaryCallback)) return null;
    if (notes?.thenVsNow.some((t) => isDuplicateNote(opener, t))) return null;
    if (isDuplicateNote(opener, notes?.whatChanged)) return null;
    return opener;
  }, [needsHeavyMemoryBlocks, entry, allEntries, notes]);

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
    if (!needsHeavyMemoryBlocks || !entry) return [];
    const raw = entryResurfacingNotes(allEntries, entry.id, limits.resurfacing);
    const shown = [
      continuationOpener,
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, limits.resurfacing);
  }, [needsHeavyMemoryBlocks, entry, allEntries, notes, continuationOpener, limits.resurfacing]);

  const timeMemory = useMemo(() => {
    if (!needsHeavyMemoryBlocks || !entry) return [];
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
    if (!needsHeavyMemoryBlocks || !entry) return [];
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
    if (!needsHeavyMemoryBlocks || !entry) return [];
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
  }, [needsHeavyMemoryBlocks, entry, allEntries, notes, continuationOpener, resurfacing, timeMemory, revisitation, limits.changeMoments]);

  const familiarity = useMemo(() => {
    if (!needsHeavyMemoryBlocks || !entry) return [];
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
    if (!needsHeavyMemoryBlocks || !entry) return [];
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

  const clarityResurfaceNote = useMemo(() => {
    if (!entry?.transcript?.trim()) return null;
    return buildClarityResurfacingNote(entry.transcript, entry.id);
  }, [entry?.id, entry?.transcript]);

  useEffect(() => {
    if (!clarityResurfaceNote || !entry) return;
    writeTrackThoughtPatternResurfaced(entry.id, clarityResurfaceNote.id);
  }, [clarityResurfaceNote?.id, entry?.id]);

  const followupNotes = useMemo(() => {
    if (!needsHeavyMemoryBlocks || !entry) return [];
    return [
      clarityResurfaceNote,
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
    clarityResurfaceNote,
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

  const handleRecordAgain = (prompt: FollowupPrompt) => {
    if (entry && revisitExperience?.isRevisit) {
      trackRevisitFollowupStarted(entry.id, prompt.id);
    }
    if (prompt.noteId) {
      trackFollowupRecordingStarted(prompt.noteId, prompt.id);
    }
    storeRecordReturnContext(buildRecordReturnFromFollowup(prompt));
    router.push("/#recorder");
  };

  const [postSaveContinuity, setPostSaveContinuity] = useState<{
    text: string;
  } | null>(null);
  const [clarityOffer, setClarityOffer] = useState<ClarityPromptOffer | null>(null);

  useEffect(() => {
    if (!freshQuiet || !entry) {
      setPostSaveContinuity(null);
      return;
    }
    const clarityLine = consumeClarityAfterSaveLine();
    const deferred = consumeAfterSaveContinuityLine();
    const line = clarityLine ?? deferred?.text ?? null;
    setPostSaveContinuity(line ? { text: line } : null);
  }, [freshQuiet, entry?.id]);

  useEffect(() => {
    if (!entry?.transcript || pending || freshQuiet || revisitExperience?.isRevisit) {
      setClarityOffer(null);
      return;
    }
    const id = requestAnimationFrame(() => {
      setClarityOffer(readClarityPromptOffer(entry.id));
      const signals = detectThinkingOutLoudSignals(entry.transcript);
      if (qualifiesForClarityPrompt(signals)) {
        writeEnqueueThoughtPatternExtract({
          entryId: entry.id,
          transcript: entry.transcript,
        });
      }
    });
    return () => cancelAnimationFrame(id);
  }, [entry?.id, entry?.transcript, freshQuiet, pending, revisitExperience?.isRevisit]);

  const revisitVoicePair = useMemo(() => {
    if (!entry || pending || !revisitExperience?.isRevisit) return null;
    return resolveRevisitVoicePlaybackPair(entry, allEntries, {
      contrast: revisitExperience.thenVsNow,
      reward: revisitExperience.revisitReward,
    });
  }, [entry, allEntries, pending, revisitExperience]);

  const voicePlaybackPair = useMemo(() => {
    if (!needsHeavyMemoryBlocks || !entry) return null;
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

  const showQuietContext = !pending && !freshQuiet && !revisitExperience?.isRevisit;

  const entryThreads = useMemo(() => {
    if (!showQuietContext || !entry) return [];
    return threadsForEntry(allEntries, entry.id, 3);
  }, [showQuietContext, entry, allEntries]);

  const entryTerritories = useMemo(() => {
    if (!showQuietContext || !entry) return [];
    return territoriesForEntry(allEntries, entry.id, 3);
  }, [showQuietContext, entry, allEntries]);

  const relationshipNotes = useMemo(() => {
    if (!needsHeavyMemoryBlocks || !entry) return [];
    return entryRelationshipNotes(allEntries, entry.id, 2);
  }, [needsHeavyMemoryBlocks, entry, allEntries]);

  const milestoneNotes = useMemo(() => {
    if (!needsHeavyMemoryBlocks || !entry) return [];
    return entryMilestoneNotes(allEntries, entry.id, limits.milestones);
  }, [needsHeavyMemoryBlocks, entry, allEntries, limits.milestones]);

  const memoryContinuity = useMemo(() => {
    if (!needsHeavyMemoryBlocks || !entry) return null;
    return buildMemoryContinuityReport(entry, allEntries);
  }, [needsHeavyMemoryBlocks, entry, allEntries]);

  const evidenceBackedMoment = useMemo(() => {
    if (!heavyReady) return null;
    return pickEvidenceBackedEntryMoment(presentation?.primaryMoment, allEntries);
  }, [heavyReady, presentation?.primaryMoment, allEntries]);

  const freshContinuation = useMemo(() => {
    const continuation = presentation?.continuation;
    if (!continuation) return null;
    if (evidenceBackedMoment && isDuplicateNote(continuation, evidenceBackedMoment)) return null;
    return continuation;
  }, [presentation?.continuation, evidenceBackedMoment]);

  return (
    <div className="min-h-screen-mobile mobile-entry-scroll bg-background pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader compact />

        <PrimaryMain className="mt-2 sm:mt-4">
        <div className="flex items-center justify-between gap-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/journal">
              <ArrowLeft className="h-4 w-4" aria-hidden />
              Reflections
            </Link>
          </Button>
          {!loading && entry ? (
            <Button
              variant="ghost"
              size="sm"
              onClick={handleDelete}
              aria-label="Delete reflection"
            >
              <Trash2 className="h-4 w-4" aria-hidden />
              Delete
            </Button>
          ) : null}
        </div>

        {loading ? (
          <div className="mt-8 space-y-8">
            <h1 className="sr-only">Reflection</h1>
            <Skeleton className="h-8 w-48" />
            <Skeleton className="h-32 w-full" />
          </div>
        ) : !entry ? (
          <MotionPage className="mt-16 text-center">
            <h1 className="text-lg font-normal text-zinc-100">Reflection not found</h1>
            <p className="mt-2 text-sm text-muted">
              This link may be outdated, or the reflection was removed from this device.
            </p>
            <Button asChild className="mt-6" variant="ghost">
              <Link href="/journal">Back to reflections</Link>
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
                  onRecordAgain={handleRecordAgain}
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
              {!freshQuiet ? (
                <>
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
                </>
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
                  <p className="mobile-prose text-zinc-400/90">{entry.transcript}</p>
                ) : null}
                {entry.transcript && !pending ? (
                  <>
                    {clarityOffer &&
                    !freshQuiet &&
                    !reflexSilenceFirst &&
                    !revisitExperience?.isRevisit ? (
                      <SortThisOutAloudPrompt
                        offer={clarityOffer}
                        anchorSnippet={entry.transcript}
                      />
                    ) : null}
                    <OpenLoopNextStepPrompt
                      entry={entry}
                      isRevisit={Boolean(revisitExperience?.isRevisit)}
                    />
                    <OpenLoopEntryContinuity entryId={entry.id} />
                    {!freshQuiet && !reflexSilenceFirst ? (
                      <CirclingThoughtsSection entryId={entry.id} />
                    ) : null}
                  </>
                ) : null}
              </section>
            ) : null}

            <EntryPhotoAttachment
              entryId={entry.id}
              photo={entry.photo}
              collapsed={freshQuiet}
              onPhotoChange={(photo) => setEntry((current) => (current ? { ...current, photo } : current))}
            />

            <EntryAtmosphereAttachment
              entryId={entry.id}
              entry={entry}
              atmosphere={entry.atmosphere}
              collapsed={freshQuiet}
              onAtmosphereChange={(atmosphere) =>
                setEntry((current) => (current ? { ...current, atmosphere } : current))
              }
            />

            {!freshQuiet && !pending && memoryContinuity?.hasData ? (
              <MemoryContinuitySection report={memoryContinuity} />
            ) : null}

            {pending ? (
              <ReflectOnEntryButton
                entryId={entry.id}
                onComplete={(updated) => setEntry(updated)}
              />
            ) : freshQuiet ? (
              <>
                {postSaveContinuity ? (
                  <p className="text-sm leading-[1.75] text-zinc-400/95">
                    {postSaveContinuity.text}
                  </p>
                ) : activeFollowup ? (
                  <FollowupPromptInline
                    prompt={activeFollowup}
                    onRecordAgain={handleRecordAgain}
                  />
                ) : freshContinuation ? (
                  <ContinuationNotes notes={[freshContinuation]} max={1} />
                ) : evidenceBackedMoment ? (
                  <EntryPrimaryCallback note={evidenceBackedMoment} />
                ) : (
                  <p className="text-sm leading-[1.75] text-zinc-500/90">
                    {FRESH_ENTRY_NO_CALLBACK_LINE}
                  </p>
                )}

                <div className="pt-2">
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="text-zinc-500 hover:text-zinc-300"
                    onClick={expandFreshQuiet}
                  >
                    More for this entry
                  </Button>
                </div>
              </>
            ) : revisitExperience?.isRevisit ? null : quiet ? (
                  <>
                    {presentation?.continuation ? (
                      <ContinuationNotes notes={[presentation.continuation]} max={1} />
                    ) : null}

                    <ThreadMentionsSection threads={entryThreads} />
                    <TerritoryMentionsSection territories={entryTerritories} />

                    {presentation?.primaryMoment ? (
                      <EntryPrimaryCallback note={presentation.primaryMoment} />
                    ) : null}

                    <FollowupPromptInline
                      prompt={activeFollowup}
                      onRecordAgain={handleRecordAgain}
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
                <TerritoryMentionsSection territories={entryTerritories} />

                <RelationshipContinuityNotes notes={relationshipNotes} max={2} />

                <MilestoneNotes
                  milestones={milestoneNotes}
                  entries={allEntries}
                  max={limits.milestones}
                />

                <MotionNoteList className="space-y-20">
                  {notes?.primaryCallback ? (
                    <EntryPrimaryCallback note={notes.primaryCallback} />
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
                  onRecordAgain={handleRecordAgain}
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
        </PrimaryMain>
      </div>
    </div>
  );
}
