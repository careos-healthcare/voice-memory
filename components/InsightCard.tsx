"use client";

import { useMemo, type ComponentType } from "react";
import { motion } from "framer-motion";
import {
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
  calmMode?: boolean;
}

function SafetyNotice() {
  return (
    <div className="flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
      <Shield className="mt-0.5 h-4 w-4 shrink-0 text-zinc-400" />
      <p className="text-xs leading-relaxed text-zinc-500">
        A mirror for your words — not therapy, not medical advice, not a
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

function MoodSummaryCard({
  reflection,
  intensityPercent,
}: {
  reflection: Reflection;
  intensityPercent: number;
}) {
  return (
    <Card>
      <CardHeader className="pb-4">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Mood snapshot
            </p>
            <CardTitle className="mt-2 text-2xl capitalize">{reflection.mood}</CardTitle>
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
  calmMode = false,
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
  const calmMirror = calmMode ? mirrorRead.slice(0, 1) : mirrorRead;

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
      className={calmMode ? "space-y-8" : "space-y-4"}
    >
      {!calmMode ? <SafetyNotice /> : null}

      {calmMirror.length > 0 && !hideObservations ? (
        <Card className={calmMode ? "border-white/5 bg-white/[0.02]" : "border-fuchsia-400/20 bg-gradient-to-br from-fuchsia-500/10 via-transparent to-transparent"}>
          <CardHeader className="pb-2">
            {!calmMode ? (
              <>
                <p className="text-xs uppercase tracking-[0.2em] text-fuchsia-300/80">
                  Your own words
                </p>
                <CardTitle className="text-lg">What your words show</CardTitle>
              </>
            ) : (
              <CardTitle className="text-base font-medium text-zinc-300">This entry</CardTitle>
            )}
          </CardHeader>
          <CardContent className="space-y-4">
            {calmMirror.map((row) => (
              <div key={row.key}>
                {!calmMode ? (
                  <p className="text-[10px] uppercase tracking-wider text-zinc-500">
                    {row.label}
                  </p>
                ) : null}
                <p className={`leading-relaxed text-zinc-200 ${calmMode ? "text-base" : "mt-1 text-sm"}`}>
                  {row.detail}
                </p>
              </div>
            ))}
          </CardContent>
        </Card>
      ) : observations.length > 0 && !hideObservations && !calmMode ? (
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

      {!calmMode ? (
        <>
          <PatternSection
            title="What repeats"
            icon={Repeat2}
            accent="text-violet-300"
            items={(patternInsights?.recurringPatterns ?? []).map((detail, i) => ({
              key: `pattern-${i}`,
              detail,
            }))}
            emptyLabel={
              reflection.recurringThemes.length > 0
                ? `Themes in this entry: ${reflection.recurringThemes.join(", ")}`
                : "More history helps repeats stand out."
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
        </>
      ) : null}

      {!hideMoodSummary && !calmMode ? (
        <MoodSummaryCard reflection={reflection} intensityPercent={intensityPercent} />
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

export {
  ErrorBanner,
  InsightCardSkeleton,
  ProcessingStatus,
} from "@/components/InsightCardStatus";
