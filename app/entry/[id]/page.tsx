"use client";

import { useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Trash2 } from "lucide-react";

import { FeedbackPrompt } from "@/components/FeedbackPrompt";
import { InsightCard } from "@/components/InsightCard";
import { VoicePlayback } from "@/components/VoicePlayback";
import { ShareMemoryCardButton } from "@/components/memory/ShareMemoryCardButton";
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { AvoidanceCard } from "@/components/patterns/AvoidanceCard";
import { PhraseMemoryCard } from "@/components/patterns/PhraseMemoryCard";
import { PatternInsightCard } from "@/components/patterns/PatternInsightCard";
import { EmotionalEvolutionCard } from "@/components/patterns/EmotionalEvolutionCard";
import {
  ContinuityChangeMomentsCard,
  LongitudinalContinuityCard,
} from "@/components/patterns/LongitudinalContinuityCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { deleteEntry, getAllEntries, getEntry } from "@/lib/storage";
import { detectContradictionsForEntry } from "@/lib/patterns/contradictions";
import { detectAvoidanceForEntry } from "@/lib/patterns/avoidance";
import { getPhrasesForEntry } from "@/lib/patterns/phrase-memory";
import { getEvolutionForEntry } from "@/lib/patterns/emotional-evolution";
import { getPatternInsights, type PatternInsight } from "@/lib/patterns/pattern-engine";
import { getContinuityForEntry } from "@/lib/patterns/continuity-engine";
import type { ContinuityReport } from "@/types/continuity";
import {
  hasStrongPatternEvidence,
  countsFromInsights,
} from "@/lib/patterns/evidence-priority";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export default function EntryPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const [entry, setEntry] = useState<JournalEntry | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const found = getEntry(params.id);
    setEntry(found ?? null);
    setLoading(false);
  }, [params.id]);

  const relatedContradictions = useMemo(() => {
    if (!entry) return [];
    return detectContradictionsForEntry(getAllEntries(), entry.id);
  }, [entry]);

  const relatedPhrases = useMemo(() => {
    if (!entry) return [];
    return getPhrasesForEntry(getAllEntries(), entry.id);
  }, [entry]);

  const relatedAvoidance = useMemo(() => {
    if (!entry) return [];
    return detectAvoidanceForEntry(getAllEntries(), entry.id);
  }, [entry]);

  const entryPatternInsights = useMemo((): PatternInsight[] => {
    if (!entry) return [];
    return getPatternInsights(getAllEntries(), "entry", entry.id, 8);
  }, [entry]);

  const relatedEvolution = useMemo(() => {
    if (!entry) return [];
    return getEvolutionForEntry(getAllEntries(), entry.id);
  }, [entry]);

  const entryContinuity = useMemo((): ContinuityReport | null => {
    if (!entry) return null;
    return getContinuityForEntry(getAllEntries(), entry.id, 8);
  }, [entry]);

  const strongPatterns = useMemo(
    () =>
      hasStrongPatternEvidence({
        ...countsFromInsights(entryPatternInsights),
        contradictionCount: relatedContradictions.length,
        phraseCount: relatedPhrases.length,
        avoidanceCount: relatedAvoidance.length,
        evolutionCount: relatedEvolution.length,
      }),
    [
      entryPatternInsights,
      relatedContradictions.length,
      relatedPhrases.length,
      relatedAvoidance.length,
      relatedEvolution.length,
    ],
  );

  const handleDelete = () => {
    if (!entry) return;
    deleteEntry(entry.id);
    router.push("/journal");
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-16 sm:px-6">
        <SiteHeader />

        <div className="mt-4 flex items-center justify-between gap-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/journal">
              <ArrowLeft className="h-4 w-4" />
              Reflections
            </Link>
          </Button>
          {!loading && entry ? (
            <Button variant="ghost" size="sm" onClick={handleDelete}>
              <Trash2 className="h-4 w-4" />
              Delete
            </Button>
          ) : null}
        </div>

        {loading ? (
          <div className="mt-8 space-y-4">
            <Skeleton className="h-8 w-48" />
            <Skeleton className="h-40 w-full" />
            <Skeleton className="h-32 w-full" />
            <Skeleton className="h-32 w-full" />
          </div>
        ) : !entry ? (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-16 text-center"
          >
            <p className="text-lg font-medium text-white">Entry not found</p>
            <p className="mt-2 text-sm text-zinc-400">
              This reflection may have been deleted or never saved on this device.
            </p>
            <Button asChild className="mt-6">
              <Link href="/">Record a new entry</Link>
            </Button>
          </motion.div>
        ) : (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-8"
          >
            <div className="mb-8">
              <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
                Pattern detection
              </p>
              <h1 className="mt-2 text-3xl font-semibold text-white">
                {formatEntryDate(entry.createdAt)}
              </h1>
              <p className="mt-2 text-sm text-zinc-500">
                {entry.durationSeconds}s voice note · evidence-based patterns from
                your archive · saved locally
              </p>
            </div>

            <div className="mb-6">
              <VoicePlayback
                entryId={entry.id}
                audioId={entry.audioId}
                durationSeconds={entry.durationSeconds}
              />
            </div>

            <div className="space-y-6">
              {/* 1. Pattern-first insights */}
              <PatternInsightCard
                insights={entryPatternInsights}
                title="Pattern insights for this reflection"
                subtitle="Ranked signals tied to this entry across your archive"
                maxItems={8}
                highlightEntryId={entry.id}
                hideWhenEmpty
              />

              {/* 2. Contradictions */}
              <ContradictionContinuityCard
                contradictions={relatedContradictions}
                title="Related continuity"
                subtitle="How this entry connects to tension or reversals elsewhere in your archive"
                maxItems={4}
                highlightEntryId={entry.id}
              />

              {entryContinuity?.hasData ? (
                <>
                  <ContinuityChangeMomentsCard
                    report={entryContinuity}
                    title="Change moments tied to this entry"
                    maxItems={3}
                    highlightEntryId={entry.id}
                  />
                  <LongitudinalContinuityCard
                    report={entryContinuity}
                    title="How this thread changed over time"
                    subtitle="Before/after shifts and continuity linked to this reflection"
                    maxItems={5}
                    highlightEntryId={entry.id}
                    hideWhenEmpty
                    showSummaries={false}
                    showArcs
                    showIdentity
                  />
                </>
              ) : null}

              {/* 3. Repeated language */}
              <PhraseMemoryCard
                phrases={relatedPhrases}
                title="Related repeated phrases"
                subtitle="Language from this entry that also appears elsewhere in your archive"
                maxItems={6}
                highlightEntryId={entry.id}
                hideWhenEmpty
              />

              <AvoidanceCard
                signals={relatedAvoidance}
                title="Indirect language in this reflection"
                subtitle="Vague or hedging phrasing connected to patterns elsewhere in your archive"
                maxItems={4}
                highlightEntryId={entry.id}
                hideWhenEmpty
              />

              {/* 4. Emotional evolution */}
              <EmotionalEvolutionCard
                insights={relatedEvolution}
                title="Emotional context for this entry"
                subtitle="Cycles and intensity patterns linked to this reflection"
                maxItems={4}
                hideWhenEmpty
              />

              {/* 5–6. Entry detail + mood (deprioritized when pattern evidence is strong) */}
              <InsightCard
                reflection={entry.reflection}
                transcript={entry.transcript}
                showTranscript
                entry={entry}
                showContradictionCard={false}
                showPhraseCard={false}
                showAvoidanceCard={false}
                hideMoodSummary={strongPatterns}
                hideObservations={strongPatterns}
              />

              <FeedbackPrompt
                kind="entry_reflection"
                targetKey={entry.id}
                label="Were these pattern observations useful?"
              />

              <ShareMemoryCardButton kind="entry_observation" entry={entry} />
            </div>
          </motion.div>
        )}
      </div>
    </div>
  );
}
