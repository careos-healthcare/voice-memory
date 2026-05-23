"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { CalendarRange, Clock3 } from "lucide-react";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { WhatChangedCard } from "@/components/patterns/WhatChangedCard";
import {
  ContinuityCallbacks,
  MemoryLandmarksStrip,
} from "@/components/patterns/ContinuityCallbacks";
import { CalmUnderstandingCard } from "@/components/patterns/CalmUnderstandingCard";
import { SeeMorePanel } from "@/components/patterns/SeeMorePanel";
import { EmotionalEvolutionCard } from "@/components/patterns/EmotionalEvolutionCard";
import { LongitudinalContinuityCard } from "@/components/patterns/LongitudinalContinuityCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { buildCalmnessReport } from "@/lib/patterns/calmness";
import { getChangesForTimeline } from "@/lib/patterns/changes";
import { getContinuityForMemory } from "@/lib/patterns/continuity-moments";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import {
  buildEmotionalEvolutionReport,
  type EmotionalEvolutionReport,
} from "@/lib/patterns/emotional-evolution";
import { getTimelineContinuity } from "@/lib/patterns/continuity-engine";
import { getAllEntries } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { CalmnessReport } from "@/types/calmness";
import type { ChangeDetectionReport } from "@/types/changes";
import type { ContinuityMomentsReport } from "@/types/continuity-moments";
import type { ContinuityReport } from "@/types/continuity";
import type { JournalEntry } from "@/types/journal";

export default function TimelinePage() {
  const { quiet, limits } = useQuietMode();
  const [report, setReport] = useState<EmotionalEvolutionReport | null>(null);
  const [calm, setCalm] = useState<CalmnessReport | null>(null);
  const [changes, setChanges] = useState<ChangeDetectionReport | null>(null);
  const [continuityMoments, setContinuityMoments] = useState<ContinuityMomentsReport | null>(null);
  const [continuity, setContinuity] = useState<ContinuityReport | null>(null);
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const all = getAllEntries();
      setEntries(all);
      setReport(buildEmotionalEvolutionReport(all));
      setCalm(buildCalmnessReport(all, { scope: "archive", limit: 3 }));
      setChanges(getChangesForTimeline(all, limits.changes));
      setContinuityMoments(getContinuityForMemory(all, limits));
      setContinuity(getTimelineContinuity(all, 8));
    });
    return () => cancelAnimationFrame(id);
  }, [limits.changes, limits.callbacks, limits.landmarks]);

  const loading = report === null;
  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Timeline</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">Over time</h1>
          <p className="mt-3 text-sm leading-relaxed text-zinc-500">
            A quiet read of how your language evolves — memory continuity, not entry recap.
          </p>
        </motion.div>

        <div className={quiet ? "mt-12 space-y-16" : "mt-12 space-y-12"}>
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading your archive…
              </CardContent>
            </Card>
          ) : entries.length === 0 ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <Card className="border-dashed border-white/5">
                <CardContent className="px-6 py-16 text-center">
                  <CalendarRange className="mx-auto h-8 w-8 text-zinc-600" />
                  <p className="mt-4 text-lg font-medium text-zinc-300">No timeline yet</p>
                  <Button asChild className="mt-8" variant="secondary">
                    <Link href="/">Start recording</Link>
                  </Button>
                </CardContent>
              </Card>
            </>
          ) : (
            <>
              <WhatChangedCard
                report={
                  changes ?? {
                    changes: [],
                    hasData: false,
                    scope: "timeline",
                    generatedAt: "",
                  }
                }
                quiet={quiet}
              />

              {continuityMoments?.callbacks.length ? (
                <ContinuityCallbacks callbacks={continuityMoments.callbacks} quiet={quiet} />
              ) : null}

              {continuityMoments?.landmarks.length ? (
                <MemoryLandmarksStrip landmarks={continuityMoments.landmarks} quiet={quiet} />
              ) : null}

              {!changes?.hasData && calm?.hasData ? (
                <CalmUnderstandingCard
                  report={calm}
                  title="What stands out"
                  subtitle="Strongest signals from your archive"
                  showLandmarks
                />
              ) : null}

              {!quiet &&
              (continuity?.hasData || (report?.insights.length ?? 0) > 0 || (changes?.hasData && calm?.hasData)) ? (
                <SeeMorePanel label="See more">
                  {changes?.hasData && calm?.hasData ? (
                    <CalmUnderstandingCard
                      report={calm}
                      title="Further context"
                      showLandmarks
                    />
                  ) : null}
                  {continuity?.hasData ? (
                    <LongitudinalContinuityCard
                      report={continuity}
                      title="Continuity"
                      subtitle=""
                      maxItems={4}
                      showSummaries={false}
                      showArcs
                      showIdentity={false}
                    />
                  ) : null}
                  {(report?.insights.length ?? 0) > 0 ? (
                    <EmotionalEvolutionCard
                      insights={report!.insights}
                      title="Intensity & mood"
                      subtitle=""
                      maxItems={3}
                      weekComparison={report!.weekComparison}
                      showWeekComparison
                    />
                  ) : null}
                </SeeMorePanel>
              ) : null}

              <Card className="border-white/5 bg-transparent">
                <CardHeader className="pb-4">
                  <div className="flex items-center gap-2">
                    <Clock3 className="h-4 w-4 text-zinc-600" />
                    <CardTitle className="text-base font-medium text-zinc-400">Reflections</CardTitle>
                  </div>
                </CardHeader>
                <CardContent className="space-y-2">
                  {sorted.slice(0, 10).map((entry) => (
                    <Link
                      key={entry.id}
                      href={`/entry/${entry.id}`}
                      className="block rounded-xl px-4 py-4 transition-colors hover:bg-white/[0.03]"
                    >
                      <div className="flex justify-between gap-4">
                        <span className="text-sm text-zinc-300">{formatEntryDate(entry.createdAt)}</span>
                        <span className="text-xs capitalize text-zinc-600">
                          {entry.reflection.mood}
                        </span>
                      </div>
                    </Link>
                  ))}
                  {sorted.length > 10 ? (
                    <Button asChild variant="ghost" size="sm" className="mt-4 w-full text-zinc-600">
                      <Link href="/journal">All reflections</Link>
                    </Button>
                  ) : null}
                </CardContent>
              </Card>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
