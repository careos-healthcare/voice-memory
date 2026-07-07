"use client";

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";

import { CrossDeviceCarryoverLine } from "@/components/sync/CrossDeviceCarryoverLine";
import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";
import { QuietSilenceLine } from "@/components/restraint/QuietSilenceLine";
import { ArchiveValueMoments } from "@/components/retention/ArchiveValueMoments";
import { OpenLoopReturnPrompt } from "@/components/open-loops/OpenLoopReturnPrompt";
import { GentleReturnPrompt } from "@/components/retention/GentleReturnPrompt";
import { DayTwoReturnPrompt } from "@/components/retention/DayTwoReturnPrompt";
import { ProtectArchiveBanner } from "@/components/auth/ProtectArchiveBanner";
import { ActivationOnboarding } from "@/components/ActivationOnboarding";
import { ArchiveProgressBar } from "@/components/archive/ArchiveProgressBar";
import { ArchiveDifferenceCard } from "@/components/archive/ArchiveDifferenceCard";
import { ArchiveIdentityBar } from "@/components/archive/ArchiveIdentityBar";
import { WhatIsMyArchive } from "@/components/archive/WhatIsMyArchive";
import { HomeArchiveBeliefIntro } from "@/components/archive/HomeArchiveBeliefIntro";
import { EvidenceArchivePreview } from "@/components/product/EvidenceArchivePreview";
import { ProofWall } from "@/components/distribution/ProofWall";
import { WhatThisArchiveCanAnswer } from "@/components/archive/WhatThisArchiveCanAnswer";
import { ARCHIVE_WAYFINDING_TO_ARCHIVE } from "@/lib/product/archive-product-copy";
import { TheoryCuriosityPrompt } from "@/components/theories/TheoryCuriosityPrompt";
import { HomepageChatGptComparison } from "@/components/product/HomepageChatGptComparison";
import { ProductDemoStory } from "@/components/product/ProductDemoStory";
import { ThreeDayProofChallengeLanding } from "@/components/landing/ThreeDayProofChallengeLanding";
import { ReturningDiscoverRedirect } from "@/components/product/ReturningDiscoverRedirect";
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
import { MobileCompressedHome } from "@/components/homepage/MobileCompressedHome";
import { MobileReturningHome } from "@/components/homepage/MobileReturningHome";
import { FirstReturnMoment } from "@/components/continuity/FirstReturnMoment";
import { pickFirstReturnMoment } from "@/lib/continuity/first-return-moment";
import { MicCentricHome } from "@/components/reflex/MicCentricHome";
import { surfacedContinuityLine } from "@/lib/continuity/build-continuity-lines";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  isMobileFirstRunHome,
  isMobileReturningHome,
  isNarrowMobileViewport,
} from "@/lib/mobile/mobile-first-run";
import {
  buildRecordReturnFromFollowup,
  buildRecordReturnFromNote,
  consumeRecordReturnContext,
  peekRecordReturnContext,
} from "@/lib/reflection/record-return";
import { buildDirectRecordHref } from "@/lib/capture/direct-record";
import { shouldForceDirectMicNextSession } from "@/lib/capture/hesitation-signals";
import { hrefForRecordReturn, startRecordReturnFlow } from "@/lib/reflection/start-record-return";
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
import { observeReturnVisitForAttribution } from "@/lib/retention/return-trigger-attribution";
import { maybeDetectReturnTriggers } from "@/lib/retention/return-triggers";
import { ReturnTriggerReasonPrompt } from "@/components/retention/ReturnTriggerReasonPrompt";
import {
  HONESTY_LINE,
  DEVICE_PRIVACY_LINE,
  APP_HONESTY,
  APP_SUPPORT,
  HOMEPAGE_CLARITY,
  POSITIONING_EYEBROW,
  PRODUCT_HERO,
} from "@/lib/product-copy";
import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";
import { isReturningProductUser } from "@/lib/product/returning-home";
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
  const router = useRouter();
  const hydrated = useClientHydrated();
  const mobileFirstRun = hydrated && isMobileFirstRunHome();
  const mobileReturning = hydrated && isMobileReturningHome();
  const returningProductUser = hydrated && isReturningProductUser();
  const entriesForHome = useMemo(
    () => (hydrated ? getMemoryEligibleEntries() : []),
    [hydrated],
  );
  const firstReturnMoment = useMemo(
    () => (hydrated ? pickFirstReturnMoment(entriesForHome) : null),
    [hydrated, entriesForHome],
  );
  const desktopRecognitionCenter =
    hydrated && !isNarrowMobileViewport() && Boolean(firstReturnMoment);
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
  const captureFirstHome =
    micCentric || mobileFirstRun || mobileReturning || desktopRecognitionCenter;

  useEffect(() => {
    if (shouldForceDirectMicNextSession()) {
      router.replace(buildDirectRecordHref({ source: "reflex", autostart: true }));
      return;
    }
    markReflexPageLand();
    recordReflexAppOpen();
    markHomepageReadingStart();

    const id = requestAnimationFrame(() => {
      maybeTrackFirstSessionReturnAfterRevisit();
      maybeDetectReturnTriggers();
      observeReturnVisitForAttribution();
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
      const recognitionCentered =
        Boolean(pickFirstReturnMoment(entries)) && !isNarrowMobileViewport();
      const presentation = runPresentationBuild(() =>
        buildQuietHomepagePresentation(entries, limits),
      );
      if (!delayStack) {
        flushPresentationSideEffects(presentation.sideEffects);
      }
      const silenceEffects = getSilenceIntelligenceEffects(entries);

      if (delayStack || recognitionCentered) {
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
    router,
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
      const ctx = buildRecordReturnFromFollowup(prompt);
      startRecordReturnFlow(ctx);
      router.push(hrefForRecordReturn(ctx));
    },
    [router],
  );

  const handlePrimaryRecordAgain = useCallback(() => {
    if (!primaryNote) return;
    const ctx = buildRecordReturnFromNote(primaryNote);
    startRecordReturnFlow(ctx);
    router.push(hrefForRecordReturn(ctx));
  }, [primaryNote, router]);

  const reflexContinuityLine = surfacedContinuityLine(
    reflexCapture?.continuityLine ?? recorderLine ?? recordReturn?.anchorQuote ?? null,
    getMemoryEligibleEntries(),
  );

  return (
    <div className="relative min-h-screen-mobile overflow-hidden bg-zinc-950 pb-safe">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-0 h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/20 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-[280px] w-[280px] rounded-full bg-fuchsia-600/10 blur-3xl" />
      </div>

      <HomepagePrimaryCtaProvider>
      <Suspense fallback={null}>
        <ReturningDiscoverRedirect />
      </Suspense>
      <div className="relative mx-auto flex min-h-screen-mobile max-w-3xl flex-col px-4 pb-10 sm:px-6">
        {!captureFirstHome ? (
          <SiteHeader compact={mobileFirstRun || mobileReturning} />
        ) : null}

        {!captureFirstHome ? (
          <div className="mt-4 space-y-3">
            <ArchiveIdentityBar />
            {returningProductUser ? (
              <WhatIsMyArchive compact className="max-w-xl" entriesOverride={entriesForHome} />
            ) : null}
          </div>
        ) : null}

        {hydrated ? (
          <div className="mx-auto mt-4 w-full max-w-2xl px-4 sm:px-6">
            <ProtectArchiveBanner />
          </div>
        ) : null}

        {!micCentric && !mobileFirstRun && !mobileReturning && !desktopRecognitionCenter ? (
          <div className="mt-6 space-y-10 py-2">
            <WhatIsMyArchive className="mx-auto max-w-xl" />
            <ArchiveDifferenceCard className="mx-auto max-w-xl" />
            <ActivationOnboarding />
            <CalmComprehensionPrompt />
            <OnboardingCompletionProof />
            <CrossDeviceCarryoverLine />
            <HomeArchiveBeliefIntro className="px-1" entriesOverride={entriesForHome} />
            <ArchiveProgressBar
              surface="home"
              entriesOverride={entriesForHome}
              className="mx-auto mt-4 max-w-xl px-1"
            />
            <EvidenceArchivePreview
              className="px-1 mt-4"
              entriesOverride={entriesForHome}
              surface="home"
            />
            <ProofWall className="px-1 mt-4" />
            <WhatThisArchiveCanAnswer className="px-1 mt-4" />
            <TheoryCuriosityPrompt className="px-1" />
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
            <ReturnTriggerReasonPrompt className="px-1" />
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

        <main
          id="main-content"
          className={`flex flex-1 flex-col items-center justify-center text-center ${
            captureFirstHome ? "min-h-[70vh] py-6" : "py-10"
          }`}
        >
          {micCentric ? (
            <MicCentricHome
              continuityLine={reflexContinuityLine}
              recordReturn={recordReturn}
              clarityRecord={clarityRecord}
              reflexCapture={reflexCapture}
              recorderAutoStart={recorderAutoStart}
              quickReflection={isQuickReflectionEnabled()}
            />
          ) : desktopRecognitionCenter ? (
            <div className="flex w-full max-w-xl flex-col items-center text-center">
              <FirstReturnMoment
                entries={entriesForHome}
                presentation="quiet"
                trackShown
                className="w-full"
              />
              <div className="mt-8 w-full" ref={recorderRef} id="recorder">
                <Recorder
                  autoStart={recorderAutoStart}
                  preRecordLine={null}
                  recordReturn={recordReturn}
                  clarityRecord={clarityRecord}
                  reflexCapture={reflexCapture}
                  reflexFastBoot={directToMic || silenceFirstReflex}
                  quickReflection={isQuickReflectionEnabled()}
                />
              </div>
            </div>
          ) : mobileFirstRun ? (
            <MobileCompressedHome
              recorder={
                <div className="w-full" ref={recorderRef} id="recorder">
                  <Recorder
                    autoStart={false}
                    recordReturn={recordReturn}
                    clarityRecord={clarityRecord}
                    reflexCapture={reflexCapture}
                    reflexFastBoot
                    quickReflection={isQuickReflectionEnabled()}
                  />
                </div>
              }
            />
          ) : mobileReturning ? (
            <div className="flex w-full max-w-md flex-col items-center">
              {returningProductUser ? (
                <Link
                  href="/archive-belief"
                  className="mb-6 text-sm text-violet-300 underline-offset-2 hover:text-violet-200 hover:underline"
                >
                  {ARCHIVE_WAYFINDING_TO_ARCHIVE} →
                </Link>
              ) : null}
              <HomeArchiveBeliefIntro className="mb-4 w-full" entriesOverride={entriesForHome} />
              <ArchiveProgressBar
                surface="home"
                entriesOverride={entriesForHome}
                className="mb-4 w-full"
              />
              <WhatThisArchiveCanAnswer className="mb-4 w-full" />
              <ReturnTriggerReasonPrompt className="mb-4 w-full" />
            <MobileReturningHome
              continuityLine={reflexContinuityLine}
              recorder={
                <div className="w-full" ref={recorderRef} id="recorder">
                  <Recorder
                    autoStart={recorderAutoStart}
                    preRecordLine={recordReturn || clarityRecord ? null : recorderLine}
                    recordReturn={recordReturn}
                    clarityRecord={clarityRecord}
                    reflexCapture={reflexCapture}
                    reflexFastBoot
                    quickReflection={isQuickReflectionEnabled()}
                  />
                </div>
              }
            />
            </div>
          ) : (
            <>
              <MotionPage className="max-w-2xl">
                <p className="text-xs tracking-[0.2em] text-violet-300/70">
                  {POSITIONING_EYEBROW}
                </p>
                <h1 className="mt-5 text-4xl font-normal tracking-tight text-zinc-100 sm:text-5xl">
                  {PRODUCT_HERO.promise}
                </h1>
                <p className="mt-6 text-lg font-normal leading-relaxed text-zinc-200 sm:text-xl">
                  {PRODUCT_HERO.archiveLead}
                </p>
                <p className="mt-4 text-sm leading-relaxed text-zinc-500">{APP_SUPPORT}</p>
                <ul className="mx-auto mt-5 max-w-md space-y-2 text-left text-sm leading-relaxed text-zinc-400">
                  {LANDING_3_DAY_CHALLENGE.steps.map((step) => (
                    <li key={step.title}>{step.title}</li>
                  ))}
                </ul>
                <div className="mx-auto mt-6 flex max-w-md flex-wrap items-center justify-center gap-4">
                  <button
                    type="button"
                    className="text-sm font-medium text-violet-300 underline-offset-2 hover:text-violet-200 hover:underline"
                    data-testid="landing-primary-cta-scroll"
                    onClick={scrollToRecorder}
                  >
                    {LANDING_3_DAY_CHALLENGE.primaryCta}
                  </button>
                  <Link
                    href={LANDING_3_DAY_CHALLENGE.secondaryHref}
                    className="text-sm text-zinc-400 underline-offset-2 hover:text-zinc-200 hover:underline"
                    data-testid="landing-secondary-cta"
                  >
                    {LANDING_3_DAY_CHALLENGE.secondaryCta}
                  </Link>
                </div>
                <HomeArchiveBeliefIntro
                  className="mx-auto mt-6 max-w-md"
                  entriesOverride={entriesForHome}
                />
                <div className="mx-auto mt-8 max-w-md">
                  <ProductDemoStory />
                </div>
                <HomepageChatGptComparison />
                <ThreeDayProofChallengeLanding />
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
                  primaryActionLabel={LANDING_3_DAY_CHALLENGE.primaryCta}
                />
              </motion.div>

              <div className="mt-10 w-full text-left">
                <HabitLoopCard compact suppressRecordCta />
              </div>
            </>
          )}

          {!captureFirstHome ? (
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
                {APP_HONESTY}
              </motion.p>
            </>
          ) : null}
        </main>

        {!captureFirstHome ? <SiteFooter className="mt-auto pt-8" /> : null}
      </div>
      </HomepagePrimaryCtaProvider>
    </div>
  );
}
