"use client";

import { useMemo, type ComponentType } from "react";
import { motion } from "framer-motion";
import {
  AlertCircle,
  EyeOff,
  MessageSquareQuote,
  Repeat2,
  Shield,
  Sparkles,
  TrendingUp,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { buildEntryPatternInsights } from "@/lib/pattern-detection";
import { getStructuredAnalysis } from "@/lib/observation-language";
import { detectContradictionsForEntry } from "@/lib/patterns/contradictions";
import { getAllEntries } from "@/lib/storage";
import type { EntryPatternInsights } from "@/types/pattern-insights";
import type { JournalEntry, Reflection } from "@/types/journal";

interface InsightCardProps {
  reflection: Reflection;
  transcript?: string;
  showTranscript?: boolean;
  entryId?: string;
  entry?: JournalEntry;
  patternInsights?: EntryPatternInsights;
  showContradictionCard?: boolean;
  showPhraseCard?: boolean;
  showAvoidanceCard?: boolean;
  hideMoodSummary?: boolean;
  hideObservations?: boolean;
}

function SafetyNotice() {
  return (
    <div className="flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
      <Shield className="mt-0.5 h-4 w-4 shrink-0 text-zinc-400" />
      <p className="text-xs leading-relaxed text-zinc-500">
        Pattern detection in your words — not therapy, not medical advice, not a
        diagnosis.
      </p>
    </div>
  );
}

function PatternSection({
  title,
  icon: Icon,
  accent,
  items,
  emptyLabel,
}: {
  title: string;
  icon: ComponentType<{ className?: string }>;
  accent: string;
  items: Array<{ key: string; label?: string; detail: string }>;
  emptyLabel?: string;
}) {
  if (items.length === 0 && !emptyLabel) return null;

  return (
    <Card>
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <Icon className={`h-4 w-4 ${accent}`} />
          <CardTitle className="text-base">{title}</CardTitle>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {items.length === 0 ? (
          <p className="text-sm text-zinc-500">{emptyLabel}</p>
        ) : (
          items.map((item) => (
            <div key={item.key} className="space-y-1">
              {item.label ? (
                <p className="text-xs font-medium uppercase tracking-wider text-zinc-500">
                  {item.label}
                </p>
              ) : null}
              <p className="text-sm leading-relaxed text-zinc-300">{item.detail}</p>
            </div>
          ))
        )}
      </CardContent>
    </Card>
  );
}

export function InsightCard({
  reflection,
  transcript,
  showTranscript = false,
  entryId,
  entry,
  patternInsights: patternInsightsProp,
  showContradictionCard = true,
  showPhraseCard = true,
  showAvoidanceCard = true,
  hideMoodSummary = false,
  hideObservations = false,
}: InsightCardProps) {
  const patternInsights = useMemo(() => {
    if (patternInsightsProp) return patternInsightsProp;
    const resolvedEntry =
      entry ?? (entryId ? getAllEntries().find((e) => e.id === entryId) : undefined);
    if (!resolvedEntry) return null;
    return buildEntryPatternInsights(resolvedEntry, getAllEntries());
  }, [patternInsightsProp, entry, entryId]);

  const resolvedEntry = useMemo(
    () => entry ?? (entryId ? getAllEntries().find((e) => e.id === entryId) : undefined),
    [entry, entryId],
  );

  const entryContradictions = useMemo(() => {
    if (!resolvedEntry) return [];
    return detectContradictionsForEntry(getAllEntries(), resolvedEntry.id);
  }, [resolvedEntry]);

  const intensityPercent = reflection.emotionalIntensity * 10;

  const mirrorRead = getStructuredAnalysis(reflection);

  const observations =
    patternInsights?.observations.length
      ? patternInsights.observations
      : mirrorRead.length > 0
        ? mirrorRead.map((row) => row.detail)
        : reflection.patternObservations ?? [];

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.45, ease: "easeOut" }}
      className="space-y-4"
    >
      <SafetyNotice />

      {mirrorRead.length > 0 && !hideObservations ? (
        <Card className="border-fuchsia-400/20 bg-gradient-to-br from-fuchsia-500/10 via-transparent to-transparent">
          <CardHeader className="pb-2">
            <p className="text-xs uppercase tracking-[0.2em] text-fuchsia-300/80">
              Reflective mirror
            </p>
            <CardTitle className="text-lg">What your words show</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {mirrorRead.map((row) => (
              <div key={row.key}>
                <p className="text-[10px] uppercase tracking-wider text-zinc-500">
                  {row.label}
                </p>
                <p className="mt-1 text-sm leading-relaxed text-zinc-200">{row.detail}</p>
              </div>
            ))}
          </CardContent>
        </Card>
      ) : observations.length > 0 && !hideObservations ? (
        <Card className="border-fuchsia-400/20 bg-gradient-to-br from-fuchsia-500/10 via-transparent to-transparent">
          <CardHeader className="pb-2">
            <p className="text-xs uppercase tracking-[0.2em] text-fuchsia-300/80">
              Concrete observations
            </p>
            <CardTitle className="text-lg">What repeats in your words</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {observations.map((obs) => (
              <p key={obs} className="text-sm leading-relaxed text-zinc-200">
                {obs}
              </p>
            ))}
          </CardContent>
        </Card>
      ) : null}

      <PatternSection
        title="Recurring patterns"
        icon={Repeat2}
        accent="text-violet-300"
        items={(patternInsights?.recurringPatterns ?? []).map((detail, i) => ({
          key: `pattern-${i}`,
          detail,
        }))}
        emptyLabel={
          reflection.recurringThemes.length > 0
            ? `Themes in this entry: ${reflection.recurringThemes.join(", ")}`
            : "Patterns emerge as you add more reflections."
        }
      />

      {showContradictionCard ? (
        <ContradictionContinuityCard
          contradictions={entryContradictions}
          maxItems={3}
          highlightEntryId={resolvedEntry?.id}
        />
      ) : null}

      {showPhraseCard ? (
        <PatternSection
          title="Repeated phrases"
          icon={MessageSquareQuote}
          accent="text-emerald-300"
          items={(patternInsights?.repeatedPhrases ?? []).map((p) => ({
            key: p.phrase,
            label: p.phrase,
            detail: `${p.category.replace("_", " ")} · ${p.count} uses across ${p.entryCount} entries · e.g. ${p.example}`,
          }))}
          emptyLabel="Phrase habits appear as you accumulate entries."
        />
      ) : null}

      {showAvoidanceCard && (patternInsights?.avoidanceSignals.length ?? 0) > 0 ? (
        <PatternSection
          title="Indirect language & hedging"
          icon={EyeOff}
          accent="text-zinc-400"
          items={(patternInsights?.avoidanceSignals ?? []).map((a) => ({
            key: a.id,
            label: a.label,
            detail: a.detail,
          }))}
        />
      ) : null}

      {(patternInsights?.emotionalEvolution.length ?? 0) > 0 ? (
        <PatternSection
          title="Emotional shift"
          icon={TrendingUp}
          accent="text-sky-300"
          items={(patternInsights?.emotionalEvolution ?? []).map((e) => ({
            key: e.id,
            label: e.label,
            detail: e.detail,
          }))}
        />
      ) : null}

      {!hideMoodSummary ? (
        <Card>
          <CardHeader className="pb-4">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
                  Mood snapshot
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
            <div className="flex flex-wrap gap-2">
              {reflection.recurringThemes.length > 0 ? (
                reflection.recurringThemes.map((theme) => (
                  <Badge key={theme} variant="default">
                    {theme}
                  </Badge>
                ))
              ) : (
                <span className="text-sm text-zinc-500">No themes tagged</span>
              )}
            </div>
          </CardContent>
        </Card>
      ) : null}

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

export function ProcessingStatus({
  stage,
}: {
  stage: "transcribing" | "analyzing" | "saving";
}) {
  const labels = {
    transcribing: "Listening to your voice…",
    analyzing: "Detecting patterns in what you said…",
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
          Pattern detection — not therapy or diagnosis.
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
