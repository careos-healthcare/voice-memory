"use client";

import { useMemo, type ComponentType } from "react";
import { motion } from "framer-motion";
import {
  EyeOff,
  MessageSquareQuote,
  Repeat2,
  Shield,
  Mic,
  TrendingUp,
} from "lucide-react";

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
  hideObservations = false,
  calmMode = true,
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
                <CardTitle className="text-lg">You said this before</CardTitle>
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
      ) : null}

      {!calmMode && !hideObservations ? (
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
              title="How this thread shifted"
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

      {showTranscript && transcript ? (
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center gap-2">
              <Mic className="h-4 w-4 text-zinc-400" />
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
