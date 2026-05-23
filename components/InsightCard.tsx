"use client";

import { motion } from "framer-motion";
import {
  AlertCircle,
  Brain,
  Heart,
  Lightbulb,
  Sparkles,
  Target,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { Reflection } from "@/types/journal";

interface InsightCardProps {
  reflection: Reflection;
  transcript?: string;
  showTranscript?: boolean;
}

const sections = [
  {
    key: "hiddenConcern" as const,
    label: "Hidden concern",
    icon: Brain,
    accent: "text-amber-300",
  },
  {
    key: "positiveSignal" as const,
    label: "Positive signal",
    icon: Heart,
    accent: "text-emerald-300",
  },
  {
    key: "recommendation" as const,
    label: "One recommendation",
    icon: Lightbulb,
    accent: "text-violet-300",
  },
];

export function InsightCard({
  reflection,
  transcript,
  showTranscript = false,
}: InsightCardProps) {
  const intensityPercent = reflection.emotionalIntensity * 10;

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.45, ease: "easeOut" }}
      className="space-y-4"
    >
      <Card className="overflow-hidden border-violet-400/20 bg-gradient-to-br from-violet-500/10 via-transparent to-transparent">
        <CardHeader className="pb-4">
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
                Mood
              </p>
              <CardTitle className="mt-2 text-2xl capitalize">
                {reflection.mood}
              </CardTitle>
            </div>
            <div className="rounded-2xl border border-white/10 bg-black/20 px-4 py-3 text-right">
              <p className="text-xs text-zinc-400">Intensity</p>
              <p className="text-2xl font-semibold text-white">
                {reflection.emotionalIntensity}
                <span className="text-sm font-normal text-zinc-500">/10</span>
              </p>
            </div>
          </div>
          <div className="mt-4 h-2 overflow-hidden rounded-full bg-white/10">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${intensityPercent}%` }}
              transition={{ duration: 0.8, delay: 0.2, ease: "easeOut" }}
              className="h-full rounded-full bg-gradient-to-r from-violet-500 to-fuchsia-400"
            />
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-2 text-sm text-zinc-400">
            <Target className="h-4 w-4" />
            <span>Recurring themes</span>
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            {reflection.recurringThemes.map((theme) => (
              <Badge key={theme} variant="default">
                {theme}
              </Badge>
            ))}
          </div>
        </CardContent>
      </Card>

      {sections.map((section, index) => {
        const Icon = section.icon;

        return (
          <motion.div
            key={section.key}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.4, delay: 0.1 * (index + 1) }}
          >
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <Icon className={`h-4 w-4 ${section.accent}`} />
                  <CardTitle className="text-base">{section.label}</CardTitle>
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-sm leading-relaxed text-zinc-300">
                  {reflection[section.key]}
                </p>
              </CardContent>
            </Card>
          </motion.div>
        );
      })}

      {showTranscript && transcript ? (
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-zinc-400" />
              <CardTitle className="text-base">Your words</CardTitle>
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed text-zinc-400">{transcript}</p>
          </CardContent>
        </Card>
      ) : null}
    </motion.div>
  );
}

export function InsightCardSkeleton() {
  return (
    <div className="space-y-4">
      <Card className="p-6">
        <div className="flex justify-between">
          <div className="h-8 w-32 animate-pulse rounded-lg bg-white/10" />
          <div className="h-12 w-16 animate-pulse rounded-xl bg-white/10" />
        </div>
        <div className="mt-4 h-2 animate-pulse rounded-full bg-white/10" />
      </Card>
      {[1, 2, 3].map((item) => (
        <Card key={item} className="p-6">
          <div className="h-4 w-28 animate-pulse rounded bg-white/10" />
          <div className="mt-4 h-16 animate-pulse rounded-xl bg-white/10" />
        </Card>
      ))}
    </div>
  );
}

export function ProcessingStatus({
  stage,
}: {
  stage: "transcribing" | "analyzing" | "saving";
}) {
  const labels = {
    transcribing: "Listening to your voice…",
    analyzing: "Finding patterns in what you shared…",
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
          This usually takes a few seconds.
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
