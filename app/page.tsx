"use client";

import { motion } from "framer-motion";
import Link from "next/link";

import { HabitLoopCard } from "@/components/HabitLoopCard";
import { ContextualReminderCards } from "@/components/reminders/ContextualReminderCards";
import { Recorder } from "@/components/Recorder";
import { SiteHeader } from "@/components/SiteHeader";

export default function HomePage() {
  return (
    <div className="relative min-h-screen overflow-hidden bg-zinc-950">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-0 h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/20 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-[280px] w-[280px] rounded-full bg-fuchsia-600/10 blur-3xl" />
      </div>

      <div className="relative mx-auto flex min-h-screen max-w-3xl flex-col px-4 pb-10 sm:px-6">
        <SiteHeader />

        <main className="flex flex-1 flex-col items-center justify-center py-8 text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="max-w-2xl"
          >
            <p className="text-xs uppercase tracking-[0.25em] text-violet-300/80">
              Voice journal
            </p>
            <h1 className="mt-4 text-4xl font-semibold tracking-tight text-white sm:text-5xl">
              VoiceMemory
            </h1>
            <p className="mt-4 text-lg text-zinc-400 sm:text-xl">
              Talk for 60 seconds. Understand yourself better.
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
            Record a quick voice note. We transcribe it, reflect on mood and
            themes, and save everything locally on your device.
          </motion.p>
        </main>

        <footer className="mt-auto flex flex-wrap justify-center gap-4 pt-8 text-center text-xs text-zinc-600">
          <Link href="/pricing" className="hover:text-zinc-400">
            Pricing →
          </Link>
          <Link href="/reminders" className="hover:text-zinc-400">
            Reminders →
          </Link>
          <Link href="/journal" className="hover:text-zinc-400">
            Journal →
          </Link>
          <Link href="/export" className="hover:text-zinc-400">
            Export →
          </Link>
          <Link href="/memory" className="hover:text-zinc-400">
            Memory →
          </Link>
          <Link href="/weekly" className="hover:text-zinc-400">
            Weekly →
          </Link>
          <Link href="/insights" className="hover:text-zinc-400">
            Insights →
          </Link>
          <Link href="/search" className="hover:text-zinc-400">
            Search →
          </Link>
        </footer>
      </div>
    </div>
  );
}
