"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";

import { CrossDeviceCarryoverLine } from "@/components/sync/CrossDeviceCarryoverLine";
import { ArchiveOwnershipSparseLine } from "@/components/archive/ArchiveOwnershipSparseLine";
import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";
import { ActivationOnboarding } from "@/components/ActivationOnboarding";
import { OnboardingCompletionProof } from "@/components/social-proof/OnboardingCompletionProof";
import { ContinuityDepthNote } from "@/components/memory/ContinuityDepthNote";
import { ArchiveGravityNote } from "@/components/memory/ArchiveGravityNote";
import { LivingResurfacingNote } from "@/components/memory/LivingResurfacingNote";
import { RevisitRhythmNote } from "@/components/memory/RevisitRhythmNote";
import { PrimaryCallbackNote } from "@/components/memory/PrimaryCallbackNote";
import { PersonalisationProgressNote } from "@/components/PersonalisationProgressNote";
import { ReflectionGoalHint } from "@/components/ReflectionGoalHint";
import { ContinuationNotes } from "@/components/patterns/MemoryNote";
import { ContextualReminderCards } from "@/components/reminders/ContextualReminderCards";
import { Recorder } from "@/components/Recorder";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { MotionPage } from "@/components/motion/MotionPage";
import { consumeStoredFollowupPrompt, storeFollowupPrompt } from "@/lib/conversation/followup-prompts";
import { buildQuietHomepagePresentation } from "@/lib/refinement/quiet-presentation";
import { homepageArchiveGravityMoment } from "@/lib/refinement/archive-gravity";
import { homepageLivingResurfacingMoment } from "@/lib/memory/living-resurfacing";
import {
  homepageRevisitRhythmMoment,
  revisitRhythmKindFromNote,
  trackRevisitRhythmSeen,
} from "@/lib/refinement/revisit-rhythm";
import { maybeTrackFirstSessionReturnAfterRevisit } from "@/lib/marketing/first-session-comprehension";
import { checkVoluntaryReturns } from "@/lib/retention/retention-loops";
import {
  HONESTY_LINE,
  POSITIONING_EYEBROW,
  POSITIONING_LEAD,
  POSITIONING_SUPPORT,
  POSITIONING_TAGLINE,
} from "@/lib/product-copy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { MOTION } from "@/lib/motion/tokens";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { MemoryNote } from "@/types/memory-note";
import type { ContinuityDepthIndicator } from "@/types/continuity-depth";

export default function HomePage() {
  const { limits } = useQuietMode();
  const [primaryNote, setPrimaryNote] = useState<MemoryNote | null>(null);
  const [continuation, setContinuation] = useState<MemoryNote[]>([]);
  const [followupPrompt, setFollowupPrompt] = useState<FollowupPrompt | null>(null);
  const [recorderLine, setRecorderLine] = useState<string | null>(null);
  const [continuityDepth, setContinuityDepth] = useState<ContinuityDepthIndicator | null>(null);
  const [archiveGravity, setArchiveGravity] = useState<MemoryNote | null>(null);
  const [livingResurfacing, setLivingResurfacing] = useState<MemoryNote | null>(null);
  const [revisitRhythm, setRevisitRhythm] = useState<MemoryNote | null>(null);
  const [reflectionPrompt, setReflectionPrompt] = useState<string | null>(null);
  const recorderRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      maybeTrackFirstSessionReturnAfterRevisit();
      checkVoluntaryReturns();
      const entries = getMemoryEligibleEntries();
      const presentation = buildQuietHomepagePresentation(entries, limits);
      setPrimaryNote(presentation.primaryNote);
      setContinuation(presentation.continuation);
      setFollowupPrompt(presentation.followupPrompt);
      setRecorderLine(presentation.recorderLine);
      setContinuityDepth(presentation.continuityDepth);
      setArchiveGravity(homepageArchiveGravityMoment(entries));
      setLivingResurfacing(homepageLivingResurfacingMoment(entries));
      setRevisitRhythm(homepageRevisitRhythmMoment(entries));
    });
    return () => cancelAnimationFrame(id);
  }, [
    limits.resurfacing,
    limits.familiarity,
    limits.rhythm,
    limits.familiarityResurfacing,
    limits.archiveGrowth,
    limits.continuation,
  ]);

  useEffect(() => {
    if (!revisitRhythm) return;
    const kind = revisitRhythmKindFromNote(revisitRhythm);
    if (!kind) return;
    trackRevisitRhythmSeen(revisitRhythm.id, kind);
  }, [revisitRhythm?.id]);

  useEffect(() => {
    const stored = consumeStoredFollowupPrompt();
    if (!stored) return;
    setReflectionPrompt(stored);
    const id = requestAnimationFrame(() => {
      recorderRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const handleContinueFollowup = useCallback((prompt: FollowupPrompt) => {
    storeFollowupPrompt(prompt);
    setReflectionPrompt(prompt.text);
    requestAnimationFrame(() => {
      recorderRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    });
  }, []);

  return (
    <div className="relative min-h-screen overflow-hidden bg-zinc-950">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-0 h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/20 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-[280px] w-[280px] rounded-full bg-fuchsia-600/10 blur-3xl" />
      </div>

      <div className="relative mx-auto flex min-h-screen max-w-3xl flex-col px-4 pb-10 sm:px-6">
        <SiteHeader />

        <div className="mt-6 space-y-10 py-2">
          <ActivationOnboarding />
          <OnboardingCompletionProof />
          <CrossDeviceCarryoverLine />
          <ArchiveOwnershipSparseLine />
          <PersonalisationProgressNote />
          <ReflectionGoalHint />
          <PrimaryCallbackNote note={primaryNote} />
          <ArchiveGravityNote note={archiveGravity} />
          <LivingResurfacingNote note={livingResurfacing} />
          <RevisitRhythmNote note={revisitRhythm} />
          <ContinuityDepthNote indicator={continuityDepth} />
          <ContinuationNotes notes={continuation} max={1} />
          <FollowupPromptInline prompt={followupPrompt} onContinue={handleContinueFollowup} />
        </div>

        <main className="flex flex-1 flex-col items-center justify-center py-10 text-center">
          <MotionPage className="max-w-2xl">
            <p className="text-xs tracking-[0.2em] text-violet-300/70">
              {POSITIONING_EYEBROW}
            </p>
            <h1 className="mt-5 text-4xl font-normal tracking-tight text-zinc-100 sm:text-5xl">
              VoiceMemory
            </h1>
            <p className="mt-4 text-base leading-relaxed text-violet-200/80 sm:text-lg">
              {POSITIONING_TAGLINE}
            </p>
            <p className="mt-5 text-lg font-normal leading-relaxed text-zinc-300/90 sm:text-xl">
              {POSITIONING_LEAD}
            </p>
            <p className="mt-4 text-sm leading-[1.75] text-zinc-500 sm:text-base">
              {POSITIONING_SUPPORT}
            </p>
          </MotionPage>

          <motion.div
            initial={{ opacity: 0, y: MOTION.offset.page }}
            animate={{ opacity: 1, y: 0 }}
            transition={{
              duration: MOTION.duration.page,
              delay: MOTION.delay.hero,
              ease: MOTION.ease,
            }}
            className="mt-10 w-full text-left"
          >
            <ContextualReminderCards />
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: MOTION.offset.page }}
            animate={{ opacity: 1, y: 0 }}
            transition={{
              duration: MOTION.duration.page,
              delay: MOTION.delay.hero * 2,
              ease: MOTION.ease,
            }}
            className="mt-8 w-full text-left"
          >
            <HabitLoopCard compact />
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: MOTION.offset.page }}
            animate={{ opacity: 1, y: 0 }}
            transition={{
              duration: MOTION.duration.page,
              delay: MOTION.delay.hero * 3,
              ease: MOTION.ease,
            }}
            className="mt-10 w-full"
            ref={recorderRef}
            id="recorder"
          >
            <Recorder
              preRecordLine={reflectionPrompt ? null : recorderLine}
              reflectionPrompt={reflectionPrompt}
            />
          </motion.div>

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: MOTION.duration.fade, delay: 0.45, ease: MOTION.ease }}
            className="mt-12 max-w-md text-sm leading-[1.75] text-zinc-500"
          >
            Speak for up to 60 seconds. Your words stay on this device.
          </motion.p>

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: MOTION.duration.fade, delay: 0.55, ease: MOTION.ease }}
            className="mt-5 max-w-md text-xs leading-relaxed text-zinc-600"
          >
            {HONESTY_LINE}
          </motion.p>
        </main>

        <SiteFooter className="mt-auto pt-8" />
      </div>
    </div>
  );
}
