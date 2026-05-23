"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { MotionPage } from "@/components/motion/MotionPage";
import { OnboardingBanner } from "@/components/OnboardingBanner";
import { ArchiveGrowthNotes, ContinuationNotes, ResurfacingNotes, RevisitationNotes, TimeMemoryNotes, FamiliarityNotes, RhythmNotes, FamiliarityResurfacingNotes } from "@/components/patterns/MemoryNote";
import { ContextualReminderCards } from "@/components/reminders/ContextualReminderCards";
import { Recorder } from "@/components/Recorder";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { homepageContinuationNotes, recorderPreRecordLine } from "@/lib/conversation/conversation-continuity";
import { homepageArchiveGrowthNotes } from "@/lib/memory/archive-growth";
import { homepageFamiliarityNotes } from "@/lib/memory/familiarity";
import { homepageFamiliarityResurfacingNotes } from "@/lib/memory/familiarity-resurfacing";
import { homepageRhythmNotes } from "@/lib/memory/rhythm-memory";
import { homepageResurfacingNotes } from "@/lib/memory/resurfacing";
import { homepageRevisitationNotes } from "@/lib/memory/revisitation";
import { homepageTimeMemoryNotes } from "@/lib/memory/time-memory";
import {
  HONESTY_LINE,
  POSITIONING_EYEBROW,
  POSITIONING_LEAD,
  POSITIONING_SUPPORT,
  POSITIONING_TAGLINE,
} from "@/lib/product-copy";
import { getAllEntries } from "@/lib/storage";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { MOTION } from "@/lib/motion/tokens";
import type { MemoryNote } from "@/types/memory-note";

export default function HomePage() {
  const { limits } = useQuietMode();
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);
  const [timeMemory, setTimeMemory] = useState<MemoryNote[]>([]);
  const [revisitation, setRevisitation] = useState<MemoryNote[]>([]);
  const [familiarity, setFamiliarity] = useState<MemoryNote[]>([]);
  const [rhythm, setRhythm] = useState<MemoryNote[]>([]);
  const [familiarityResurfacing, setFamiliarityResurfacing] = useState<MemoryNote[]>([]);
  const [archiveGrowth, setArchiveGrowth] = useState<MemoryNote[]>([]);
  const [continuation, setContinuation] = useState<MemoryNote[]>([]);
  const [recorderLine, setRecorderLine] = useState<string | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      const resurfacingNotes = homepageResurfacingNotes(entries, limits.resurfacing);
      const revisitationNotes = homepageRevisitationNotes(entries);
      const familiarityResurfacingNotes = homepageFamiliarityResurfacingNotes(
        entries,
        limits.familiarityResurfacing,
      );
      const continuationNotes = homepageContinuationNotes(entries, limits.continuation);
      setResurfacing(resurfacingNotes);
      setTimeMemory(homepageTimeMemoryNotes(entries));
      setRevisitation(revisitationNotes);
      setFamiliarity(homepageFamiliarityNotes(entries, limits.familiarity));
      setRhythm(homepageRhythmNotes(entries, limits.rhythm));
      setFamiliarityResurfacing(familiarityResurfacingNotes);
      setContinuation(continuationNotes);
      setRecorderLine(
        continuationNotes.length === 0 ? recorderPreRecordLine(entries) : null,
      );
      const meaningfulTiming =
        resurfacingNotes.length > 0 ||
        revisitationNotes.length > 0 ||
        familiarityResurfacingNotes.length > 0;
      setArchiveGrowth(
        homepageArchiveGrowthNotes(entries, meaningfulTiming).slice(0, limits.archiveGrowth),
      );
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

  return (
    <div className="relative min-h-screen overflow-hidden bg-zinc-950">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-0 h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/20 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-[280px] w-[280px] rounded-full bg-fuchsia-600/10 blur-3xl" />
      </div>

      <div className="relative mx-auto flex min-h-screen max-w-3xl flex-col px-4 pb-10 sm:px-6">
        <SiteHeader />

        <div className="mt-6 space-y-10 py-2">
          <OnboardingBanner />
          <EmptyStateIntelligence hideWhenRich />
          <ContinuationNotes notes={continuation} max={limits.continuation} />
          <ResurfacingNotes notes={resurfacing} max={limits.resurfacing} />
          <FamiliarityNotes notes={familiarity} max={limits.familiarity} />
          <FamiliarityResurfacingNotes
            notes={familiarityResurfacing}
            max={limits.familiarityResurfacing}
          />
          <RhythmNotes notes={rhythm} max={limits.rhythm} />
          <RevisitationNotes notes={revisitation} max={1} />
          <TimeMemoryNotes notes={timeMemory} max={1} />
          <ArchiveGrowthNotes notes={archiveGrowth} max={limits.archiveGrowth} />
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
          >
            <Recorder preRecordLine={recorderLine} />
          </motion.div>

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: MOTION.duration.fade, delay: 0.45, ease: MOTION.ease }}
            className="mt-12 max-w-md text-sm leading-[1.75] text-zinc-500"
          >
            Speak for up to 60 seconds. We transcribe, surface patterns in mood and
            themes, and keep everything on this device — your private memory layer.
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
