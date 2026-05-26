"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";

import { CrossDeviceCarryoverLine } from "@/components/sync/CrossDeviceCarryoverLine";
import { ArchiveOwnershipSparseLine } from "@/components/archive/ArchiveOwnershipSparseLine";
import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";
import { QuietSilenceLine } from "@/components/restraint/QuietSilenceLine";
import { ArchiveValueMoments } from "@/components/retention/ArchiveValueMoments";
import { OpenLoopReturnPrompt } from "@/components/open-loops/OpenLoopReturnPrompt";
import { GentleReturnPrompt } from "@/components/retention/GentleReturnPrompt";
import { DayTwoReturnPrompt } from "@/components/retention/DayTwoReturnPrompt";
import { ActivationOnboarding } from "@/components/ActivationOnboarding";
import { HomepagePrimaryCtaProvider } from "@/components/homepage/HomepagePrimaryCtaProvider";
import { CalmComprehensionPrompt } from "@/components/onboarding/CalmComprehensionPrompt";
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
import { MicCentricHome } from "@/components/reflex/MicCentricHome";
import {
  buildRecordReturnFromFollowup,
  buildRecordReturnFromNote,
  consumeRecordReturnContext,
  peekRecordReturnContext,
} from "@/lib/reflection/record-return";
import {
  consumeClarityRecordContext,
  peekClarityRecordContext,
  type ClarityRecordContext,
} from "@/lib/clarity/clarity-record";
import { isQuickReflectionEnabled } from "@/lib/reflection/quick-reflection";
import { flushPresentationSideEffects } from "@/lib/refinement/presentation-side-effects";
import { buildQuietHomepagePresentation } from "@/lib/refinement/quiet-presentation";
import { runPresentationBuild } from "@/lib/tracking/presentation-guard";
import { getSilenceIntelligenceEffects } from "@/lib/restraint/silence-intelligence";
import { homepageArchiveGravityMoment } from "@/lib/refinement/archive-gravity";
import { homepageLivingResurfacingMoment } from "@/lib/memory/living-resurfacing";
import {
  homepageRevisitRhythmMoment,
  revisitRhythmKindFromNote,
  trackRevisitRhythmSeen,
} from "@/lib/refinement/revisit-rhythm";
import { maybeTrackFirstSessionReturnAfterRevisit } from "@/lib/marketing/first-session-comprehension";
import { checkVoluntaryReturns } from "@/lib/retention/retention-loops";
import { maybeDetectReturnTriggers } from "@/lib/retention/return-triggers";
import {
  HONESTY_LINE,
  DEVICE_PRIVACY_LINE,
  HOMEPAGE_CLARITY,
  POSITIONING_EYEBROW,
  POSITIONING_LEAD,
  POSITIONING_SUPPORT,
  POSITIONING_TAGLINE,
} from "@/lib/product-copy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { MOTION } from "@/lib/motion/tokens";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { RecordReturnContext } from "@/types/record-return";
import type { MemoryNote } from "@/types/memory-note";
import type { ContinuityDepthIndicator } from "@/types/continuity-depth";
import { detectReflexCapture } from "@/lib/reflex/reflex-capture";
import {
  consumeReflexCaptureContext,
  storeReflexCaptureContext,
  type ReflexCaptureContext,
} from "@/lib/reflex/reflex-context";
import {
  shouldActivateReflexSilenceFirst,
  recordReflexAppOpen,
} from "@/lib/reflex/open-without-record";
import { shouldDelayHomepageContinuityStack } from "@/lib/reflex/reflex-restraint";
import {
  markHomepageReadingStart,
  markScrollBeforeRecorder,
} from "@/lib/reflex/read-vs-speak";
import {
  markReflexPageLand,
  trackReflexEvent,
  REFLEX_EVENTS,
} from "@/lib/reflex/reflex-observation";
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
  const [recordReturn, setRecordReturn] = useState<RecordReturnContext | null>(null);
  const [clarityRecord, setClarityRecord] = useState<ClarityRecordContext | null>(null);
  const [reflexCapture, setReflexCapture] = useState<ReflexCaptureContext | null>(null);
  const [directToMic, setDirectToMic] = useState(false);
  const [silenceFirstReflex, setSilenceFirstReflex] = useState(false);
  const [recorderAutoStart, setRecorderAutoStart] = useState(false);
  const recorderRef = useRef<HTMLDivElement>(null);

  const scrollToRecorder = useCallback(() => {
    markScrollBeforeRecorder();
    requestAnimationFrame(() => {
      recorderRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    });
  }, []);

  const micCentric =
    directToMic || silenceFirstReflex || Boolean(recordReturn || clarityRecord || reflexCapture);

  useEffect(() => {
    markReflexPageLand();
    recordReflexAppOpen();
    markHomepageReadingStart();

    const id = requestAnimationFrame(() => {
      maybeTrackFirstSessionReturnAfterRevisit();
      maybeDetectReturnTriggers();
      checkVoluntaryReturns();
      const entries = getMemoryEligibleEntries();

      const reflex = detectReflexCapture(entries);
      if (
        reflex.shouldBypassHomepage &&
        reflex.continuityLine &&
        reflex.triggerType
      ) {
        const ctx: ReflexCaptureContext = {
          continuityLine: reflex.continuityLine,
          triggerType: reflex.triggerType,
          anchorQuote: reflex.anchorQuote,
          noteId: reflex.noteId,
        };
        storeReflexCaptureContext(ctx);
        setReflexCapture(ctx);
        setDirectToMic(true);
        setRecorderAutoStart(true);
        trackReflexEvent(REFLEX_EVENTS.reflexMomentDetected, {
          triggerType: reflex.triggerType,
          bypassScore: String(reflex.bypassScore),
        });
        trackReflexEvent(REFLEX_EVENTS.directToMicBypass, {
          triggerType: reflex.triggerType,
        });
        return;
      }

      if (shouldActivateReflexSilenceFirst()) {
        setSilenceFirstReflex(true);
        trackReflexEvent(REFLEX_EVENTS.silenceFirstActivated);
        return;
      }

      const delayStack = shouldDelayHomepageContinuityStack();
      const presentation = runPresentationBuild(() =>
        buildQuietHomepagePresentation(entries, limits),
      );
      if (!delayStack) {
        flushPresentationSideEffects(presentation.sideEffects);
      }
      const silenceEffects = getSilenceIntelligenceEffects(entries);

      if (delayStack) {
        setPrimaryNote(null);
        setContinuation([]);
        setFollowupPrompt(null);
        setRecorderLine(null);
        setContinuityDepth(null);
        setArchiveGravity(null);
        setLivingResurfacing(null);
        setRevisitRhythm(null);
      } else {
        setPrimaryNote(presentation.primaryNote);
        setContinuation(presentation.continuation);
        setFollowupPrompt(presentation.followupPrompt);
        setRecorderLine(presentation.recorderLine);
        setContinuityDepth(presentation.continuityDepth);
        setArchiveGravity(
          silenceEffects.delayResurfacing ? null : homepageArchiveGravityMoment(entries),
        );
        setLivingResurfacing(
          silenceEffects.delayResurfacing ? null : homepageLivingResurfacingMoment(entries),
        );
        setRevisitRhythm(
          silenceEffects.delayResurfacing ? null : homepageRevisitRhythmMoment(entries),
        );
      }
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
    const clarity = consumeClarityRecordContext();
    if (clarity) {
      setClarityRecord(clarity);
      setRecorderAutoStart(true);
      scrollToRecorder();
      return;
    }
    const reflex = consumeReflexCaptureContext();
    if (reflex) {
      setReflexCapture(reflex);
      setDirectToMic(true);
      setRecorderAutoStart(true);
      scrollToRecorder();
      return;
    }
    const stored = consumeRecordReturnContext();
    if (!stored) return;
    setRecordReturn(stored);
    setRecorderAutoStart(true);
    scrollToRecorder();
  }, [scrollToRecorder]);

  const handleRecordAgain = useCallback(
    (prompt: FollowupPrompt) => {
      setRecordReturn(buildRecordReturnFromFollowup(prompt));
      setRecorderAutoStart(true);
      scrollToRecorder();
    },
    [scrollToRecorder],
  );

  const handlePrimaryRecordAgain = useCallback(() => {
    if (!primaryNote) return;
    setRecordReturn(buildRecordReturnFromNote(primaryNote));
    setRecorderAutoStart(true);
    scrollToRecorder();
  }, [primaryNote, scrollToRecorder]);

  const reflexContinuityLine =
    reflexCapture?.continuityLine ?? recordReturn?.anchorQuote ?? null;

  return (
    <div className="relative min-h-screen-mobile overflow-hidden bg-zinc-950 pb-safe">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-0 h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/20 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-[280px] w-[280px] rounded-full bg-fuchsia-600/10 blur-3xl" />
      </div>

      <HomepagePrimaryCtaProvider>
      <div className="relative mx-auto flex min-h-screen-mobile max-w-3xl flex-col px-4 pb-10 sm:px-6">
        <SiteHeader />

        {!micCentric ? (
          <div className="mt-6 space-y-10 py-2">
            <ActivationOnboarding />
            <CalmComprehensionPrompt />
            <OnboardingCompletionProof />
            <CrossDeviceCarryoverLine />
            <ArchiveOwnershipSparseLine />
            <PersonalisationProgressNote />
            <ReflectionGoalHint />
            <PrimaryCallbackNote
              note={primaryNote}
              onRecordAgain={handlePrimaryRecordAgain}
            />
            <QuietSilenceLine />
            <OpenLoopReturnPrompt
              onRecordAgain={() => {
                const stored = peekRecordReturnContext();
                if (stored) {
                  setRecordReturn(stored);
                  setRecorderAutoStart(true);
                }
                scrollToRecorder();
              }}
            />
            <GentleReturnPrompt />
            <DayTwoReturnPrompt />
            <ArchiveValueMoments />
            <ArchiveGravityNote note={archiveGravity} />
            <LivingResurfacingNote note={livingResurfacing} />
            <RevisitRhythmNote note={revisitRhythm} />
            <ContinuityDepthNote indicator={continuityDepth} />
            <ContinuationNotes notes={continuation} max={1} />
            <FollowupPromptInline
              prompt={followupPrompt}
              onRecordAgain={handleRecordAgain}
            />
          </div>
        ) : null}

        <main className="flex flex-1 flex-col items-center justify-center py-10 text-center">
          {micCentric ? (
            <MicCentricHome
              continuityLine={reflexContinuityLine}
              recordReturn={recordReturn}
              clarityRecord={clarityRecord}
              reflexCapture={reflexCapture}
              recorderAutoStart={recorderAutoStart}
              quickReflection={isQuickReflectionEnabled()}
            />
          ) : (
            <>
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
                <p className="mt-6 text-lg font-normal leading-relaxed text-zinc-200 sm:text-xl">
                  {POSITIONING_LEAD}
                </p>
                <ul className="mx-auto mt-5 max-w-md space-y-2 text-left text-sm leading-relaxed text-zinc-400">
                  <li>{HOMEPAGE_CLARITY.stepSpeak}</li>
                  <li>{HOMEPAGE_CLARITY.stepRemember}</li>
                  <li>{HOMEPAGE_CLARITY.stepReturn}</li>
                </ul>
                <div className="mx-auto mt-8 max-w-md rounded-2xl border border-white/[0.08] bg-white/[0.03] px-4 py-4 text-left">
                  <p className="text-[10px] uppercase tracking-wider text-zinc-600">
                    {HOMEPAGE_CLARITY.exampleLabel}
                  </p>
                  <p className="mt-2 text-sm leading-relaxed text-zinc-400/95">
                    {HOMEPAGE_CLARITY.example}
                  </p>
                </div>
                <p className="mt-6 text-sm leading-[1.75] text-zinc-500">{POSITIONING_SUPPORT}</p>
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
                <HabitLoopCard compact suppressRecordCta />
              </motion.div>
            </>
          )}

          {!micCentric ? (
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
              {!recordReturn && !clarityRecord ? (
                <p className="mb-4 text-center text-sm leading-relaxed text-zinc-400">
                  {HOMEPAGE_CLARITY.ctaLine}
                </p>
              ) : null}
              <Recorder
                autoStart={recorderAutoStart}
                preRecordLine={recordReturn || clarityRecord ? null : recorderLine}
                recordReturn={recordReturn}
                clarityRecord={clarityRecord}
                reflexCapture={reflexCapture}
                reflexFastBoot={directToMic || silenceFirstReflex}
                quickReflection={isQuickReflectionEnabled()}
              />
            </motion.div>
          ) : null}

          {!micCentric ? (
            <>
              <motion.p
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: MOTION.duration.fade, delay: 0.45, ease: MOTION.ease }}
                className="mt-12 max-w-md text-sm leading-[1.75] text-zinc-500"
              >
                {DEVICE_PRIVACY_LINE}
              </motion.p>

              <motion.p
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: MOTION.duration.fade, delay: 0.55, ease: MOTION.ease }}
                className="mt-5 max-w-md text-xs leading-relaxed text-zinc-600"
              >
                {HONESTY_LINE}
              </motion.p>
            </>
          ) : null}
        </main>

        {!micCentric ? <SiteFooter className="mt-auto pt-8" /> : null}
      </div>
      </HomepagePrimaryCtaProvider>
    </div>
  );
}
