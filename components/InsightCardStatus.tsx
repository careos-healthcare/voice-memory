"use client";

import { motion } from "framer-motion";
import { AlertCircle, Sparkles } from "lucide-react";

import { Card } from "@/components/ui/card";
import type { ProcessingStage } from "@/types/journal";

export function InsightCardSkeleton() {
  return (
    <div className="space-y-4">
      <div className="h-16 animate-pulse rounded-2xl bg-white/5" />
      <Card className="p-6">
        <div className="h-24 animate-pulse rounded-xl bg-white/10" />
      </Card>
      <Card className="p-6">
        <div className="flex justify-between">
          <div className="h-8 w-32 animate-pulse rounded-lg bg-white/10" />
          <div className="h-12 w-16 animate-pulse rounded-xl bg-white/10" />
        </div>
        <div className="mt-4 h-2 animate-pulse rounded-full bg-white/10" />
      </Card>
    </div>
  );
}

export function ProcessingStatus({ stage }: { stage: ProcessingStage }) {
  const labels = {
    transcribing: "Listening to your voice…",
    analyzing: "Reading your words…",
    saving: "Saving your reflection…",
  };

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.98 }}
      animate={{ opacity: 1, scale: 1 }}
      className="flex flex-col items-center gap-4 rounded-3xl border border-white/10 bg-white/[0.03] px-6 py-10 text-center"
    >
      <motion.div
        animate={{ rotate: 360 }}
        transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
        className="flex h-14 w-14 items-center justify-center rounded-full border border-violet-400/30 bg-violet-500/10"
      >
        <Sparkles className="h-6 w-6 text-violet-300" />
      </motion.div>
      <div>
        <p className="text-lg font-medium text-white">{labels[stage]}</p>
        <p className="mt-1 text-sm text-zinc-400">
          A mirror for your words — not therapy or diagnosis.
        </p>
      </div>
    </motion.div>
  );
}

export function ErrorBanner({ message }: { message: string }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className="flex items-start gap-3 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200"
    >
      <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
      <p>{message}</p>
    </motion.div>
  );
}
