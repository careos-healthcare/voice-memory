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
import { CalmUnderstandingCard } from "@/components/patterns/CalmUnderstandingCard";
import { SeeMorePanel } from "@/components/patterns/SeeMorePanel";
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { PatternInsightCard } from "@/components/patterns/PatternInsightCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { getCalmnessForEntry } from "@/lib/patterns/calmness";
import { detectContradictionsForEntry } from "@/lib/patterns/contradictions";
import { getPatternInsights } from "@/lib/patterns/pattern-engine";
import { deleteEntry, getAllEntries, getEntry } from "@/lib/storage";
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

  const allEntries = useMemo(() => getAllEntries(), [entry]);

  const calmReport = useMemo(() => {
    if (!entry) return null;
    return getCalmnessForEntry(allEntries, entry.id);
  }, [entry, allEntries]);

  const relatedContradictions = useMemo(() => {
    if (!entry) return [];
    return detectContradictionsForEntry(allEntries, entry.id);
  }, [entry, allEntries]);

  const entryPatternInsights = useMemo(() => {
    if (!entry) return [];
    return getPatternInsights(allEntries, "entry", entry.id, 8);
  }, [entry, allEntries]);

  const handleDelete = () => {
    if (!entry) return;
    deleteEntry(entry.id);
    router.push("/journal");
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
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
            className="mt-8 space-y-12"
          >
            <header>
              <h1 className="text-2xl font-semibold text-white">
                {formatEntryDate(entry.createdAt)}
              </h1>
              <p className="mt-2 text-sm text-zinc-600">{entry.durationSeconds}s · saved locally</p>
            </header>

            <VoicePlayback
              entryId={entry.id}
              audioId={entry.audioId}
              durationSeconds={entry.durationSeconds}
            />

            {calmReport?.hasData ? (
              <CalmUnderstandingCard
                report={calmReport}
                title="In context"
                subtitle="How this reflection sits in your archive"
                highlightEntryId={entry.id}
              />
            ) : null}

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

            {(entryPatternInsights.length > 0 || relatedContradictions.length > 0) ? (
              <SeeMorePanel label="See more detail">
                <PatternInsightCard
                  insights={entryPatternInsights}
                  title="Related patterns"
                  maxItems={6}
                  primaryCount={2}
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
