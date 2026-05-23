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
import {
  ContinuityCallbacks,
  MemoryLandmarksStrip,
} from "@/components/patterns/ContinuityCallbacks";
import { ThenVsNowCard } from "@/components/patterns/ThenVsNowCard";
import { SeeMorePanel } from "@/components/patterns/SeeMorePanel";
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { PatternInsightCard } from "@/components/patterns/PatternInsightCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { getContinuityForEntry } from "@/lib/patterns/continuity-moments";
import { detectContradictionsForEntry } from "@/lib/patterns/contradictions";
import { getPatternInsights } from "@/lib/patterns/pattern-engine";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { deleteEntry, getAllEntries, getEntry } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export default function EntryPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const [entry, setEntry] = useState<JournalEntry | undefined>(undefined);
  const [loading, setLoading] = useState(true);
  const { quiet, limits } = useQuietMode();

  useEffect(() => {
    const found = getEntry(params.id);
    setEntry(found ?? undefined);
    setLoading(false);
  }, [params.id]);

  const allEntries = useMemo(() => getAllEntries(), [entry]);

  const continuity = useMemo(() => {
    if (!entry) return null;
    return getContinuityForEntry(allEntries, entry.id, {
      callbacks: limits.callbacks,
      landmarks: limits.landmarks,
    });
  }, [entry, allEntries, limits.callbacks, limits.landmarks]);

  const relatedContradictions = useMemo(() => {
    if (!entry) return [];
    return detectContradictionsForEntry(allEntries, entry.id);
  }, [entry, allEntries]);

  const entryPatternInsights = useMemo(() => {
    if (!entry) return [];
    return getPatternInsights(allEntries, "entry", entry.id, 8).filter((i) =>
      helpsOrient(i.title + " " + (i.detail ?? ""), i.scores.total),
    );
  }, [entry, allEntries]);

  const handleDelete = () => {
    if (!entry) return;
    deleteEntry(entry.id);
    router.push("/journal");
  };

  const sectionGap = quiet ? "space-y-16" : "space-y-12";

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
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
          <div className="mt-8 space-y-8">
            <Skeleton className="h-8 w-48" />
            <Skeleton className="h-32 w-full" />
          </div>
        ) : !entry ? (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-16 text-center"
          >
            <p className="text-lg font-medium text-white">Entry not found</p>
            <Button asChild className="mt-6">
              <Link href="/">Record a new entry</Link>
            </Button>
          </motion.div>
        ) : (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className={`mt-8 ${sectionGap}`}
          >
            <header>
              <h1 className="text-2xl font-semibold text-white">
                {formatEntryDate(entry.createdAt)}
              </h1>
              <p className="mt-2 text-sm text-zinc-600">{entry.durationSeconds}s · saved locally</p>
            </header>

            {continuity?.callbacks.length ? (
              <ContinuityCallbacks
                callbacks={continuity.callbacks}
                title="What sounds different now"
                highlightEntryId={entry.id}
                quiet={quiet}
              />
            ) : null}

            {continuity?.thenVsNow ? (
              <ThenVsNowCard comparison={continuity.thenVsNow} />
            ) : null}

            <VoicePlayback
              entryId={entry.id}
              audioId={entry.audioId}
              durationSeconds={entry.durationSeconds}
            />

            <InsightCard
              reflection={entry.reflection}
              transcript={entry.transcript}
              showTranscript
              entry={entry}
              showContradictionCard={false}
              showPhraseCard={false}
              showAvoidanceCard={false}
              hideMoodSummary
              calmMode
            />

            {continuity?.landmarks.length ? (
              <MemoryLandmarksStrip landmarks={continuity.landmarks} quiet={quiet} />
            ) : null}

            {!quiet &&
            (entryPatternInsights.length > 0 || relatedContradictions.length > 0) ? (
              <SeeMorePanel label="See more">
                <PatternInsightCard
                  insights={entryPatternInsights}
                  title="What returned"
                  maxItems={4}
                  primaryCount={1}
                  highlightEntryId={entry.id}
                  hideWhenEmpty
                />
                <ContradictionContinuityCard
                  contradictions={relatedContradictions}
                  title="Tension elsewhere"
                  subtitle=""
                  maxItems={2}
                  highlightEntryId={entry.id}
                />
              </SeeMorePanel>
            ) : null}

            <FeedbackPrompt
              kind="entry_reflection"
              targetKey={entry.id}
              label="Did this help you orient?"
            />

            <ShareMemoryCardButton kind="entry_observation" entry={entry} />
          </motion.div>
        )}
      </div>
    </div>
  );
}
