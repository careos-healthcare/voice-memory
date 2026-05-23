"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { OnboardingBanner } from "@/components/OnboardingBanner";
import { ResurfacingNotes } from "@/components/patterns/MemoryNote";
import { ContextualReminderCards } from "@/components/reminders/ContextualReminderCards";
import { Recorder } from "@/components/Recorder";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { homepageResurfacingNotes } from "@/lib/memory/resurfacing";
import {
  HONESTY_LINE,
  POSITIONING_EYEBROW,
  POSITIONING_LEAD,
  POSITIONING_SUPPORT,
  POSITIONING_TAGLINE,
} from "@/lib/product-copy";
import { getAllEntries } from "@/lib/storage";
import type { MemoryNote } from "@/types/memory-note";

export default function HomePage() {
  const [resurfacing, setResurfacing] = useState<MemoryNote[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setResurfacing(homepageResurfacingNotes(getAllEntries()));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <div className="relative min-h-screen overflow-hidden bg-zinc-950">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-0 h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/20 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-[280px] w-[280px] rounded-full bg-fuchsia-600/10 blur-3xl" />
      </div>

      <div className="relative mx-auto flex min-h-screen max-w-3xl flex-col px-4 pb-10 sm:px-6">
        <SiteHeader />

        <div className="mt-4 space-y-4">
          <OnboardingBanner />
          <EmptyStateIntelligence hideWhenRich />
          <ResurfacingNotes notes={resurfacing} />
        </div>

        <main className="flex flex-1 flex-col items-center justify-center py-8 text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="max-w-2xl"
          >
            <p className="text-xs uppercase tracking-[0.25em] text-violet-300/80">
              {POSITIONING_EYEBROW}
            </p>
            <h1 className="mt-4 text-4xl font-semibold tracking-tight text-white sm:text-5xl">
              VoiceMemory
            </h1>
            <p className="mt-3 text-base text-violet-200/90 sm:text-lg">
              {POSITIONING_TAGLINE}
            </p>
            <p className="mt-4 text-lg text-zinc-300 sm:text-xl">{POSITIONING_LEAD}</p>
            <p className="mt-3 text-sm leading-relaxed text-zinc-500 sm:text-base">
              {POSITIONING_SUPPORT}
            </p>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55, delay: 0.06 }}
            className="mt-8 w-full text-left"
          >
            <ContextualReminderCards />
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55, delay: 0.08 }}
            className="mt-6 w-full text-left"
          >
            <HabitLoopCard compact />
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55, delay: 0.1 }}
            className="mt-8 w-full"
          >
            <Recorder />
          </motion.div>

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.3 }}
            className="mt-10 max-w-md text-sm leading-relaxed text-zinc-500"
          >
            Speak for up to 60 seconds. We transcribe, surface patterns in mood and
            themes, and keep everything on this device — your private memory layer.
          </motion.p>

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.35 }}
            className="mt-4 max-w-md text-xs leading-relaxed text-zinc-600"
          >
            {HONESTY_LINE}
          </motion.p>
        </main>

        <SiteFooter className="mt-auto pt-8" />
      </div>
    </div>
  );
}
