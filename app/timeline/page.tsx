"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { CalendarRange, Clock3, Shield } from "lucide-react";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { EmotionalEvolutionCard } from "@/components/patterns/EmotionalEvolutionCard";
import { LongitudinalContinuityCard } from "@/components/patterns/LongitudinalContinuityCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildEmotionalEvolutionReport,
  type EmotionalEvolutionReport,
} from "@/lib/patterns/emotional-evolution";
import { getTimelineContinuity } from "@/lib/patterns/continuity-engine";
import type { ContinuityReport } from "@/types/continuity";
import { getAllEntries } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export default function TimelinePage() {
  const [report, setReport] = useState<EmotionalEvolutionReport | null>(null);
  const [continuity, setContinuity] = useState<ContinuityReport | null>(null);
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const all = getAllEntries();
      setEntries(all);
      setReport(buildEmotionalEvolutionReport(all));
      setContinuity(getTimelineContinuity(all, 14));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = report === null;
  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            Longitudinal timeline
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Timeline
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            How mood, themes, and language evolve across your reflections — computed
            locally from your words.
          </p>
        </motion.div>

        <div className="mt-4 flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-xs text-zinc-500">
          <Shield className="mt-0.5 h-4 w-4 shrink-0 text-zinc-400" />
          Reflective mirror only — not therapy, not a diagnosis. These are patterns
          in how you described feeling, not clinical labels.
        </div>

        <div className="mt-6 space-y-6">
          {loading ? (
            <Card>
              <CardContent className="py-12 text-center text-sm text-zinc-500">
                Reading your local memory…
              </CardContent>
            </Card>
          ) : entries.length === 0 ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <Card className="border-dashed">
                <CardContent className="px-6 py-12 text-center">
                  <CalendarRange className="mx-auto h-8 w-8 text-violet-300" />
                  <p className="mt-4 text-lg font-medium text-white">No timeline yet</p>
                  <p className="mt-2 text-sm text-zinc-400">
                    Voice reflections build an emotional timeline — intensity drift,
                    day-of-week patterns, and recurring triggers.
                  </p>
                  <Button asChild className="mt-6 w-full sm:w-auto">
                    <Link href="/">Start recording</Link>
                  </Button>
                </CardContent>
              </Card>
            </>
          ) : (
            <>
              {continuity?.hasData ? (
                <LongitudinalContinuityCard
                  report={continuity}
                  title="Continuity over time"
                  subtitle="What changed, faded, intensified, or came back across your archive"
                  maxItems={10}
                  showSummaries
                  showArcs
                  showIdentity
                />
              ) : null}

              <EmotionalEvolutionCard
                insights={report.insights}
                title="Emotional evolution"
                subtitle="Day-of-week patterns, intensity drift, triggers, and calmer vs more intense periods"
                maxItems={10}
                weekComparison={report.weekComparison}
                showWeekComparison
              />

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <Clock3 className="h-4 w-4 text-violet-300" />
                    <CardTitle className="text-base">Reflection chronology</CardTitle>
                  </div>
                  <p className="text-xs text-zinc-500">Most recent first · tap to open</p>
                </CardHeader>
                <CardContent className="space-y-3">
                  {sorted.slice(0, 12).map((entry) => (
                    <Link
                      key={entry.id}
                      href={`/entry/${entry.id}`}
                      className="block rounded-xl border border-white/10 bg-black/20 px-4 py-3 transition-colors hover:border-violet-400/30 hover:bg-violet-500/5"
                    >
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <span className="text-sm font-medium text-white">
                          {formatEntryDate(entry.createdAt)}
                        </span>
                        <span className="text-xs capitalize text-zinc-500">
                          {entry.reflection.mood} · {entry.reflection.emotionalIntensity}/10
                        </span>
                      </div>
                      {entry.reflection.recurringThemes.length > 0 ? (
                        <p className="mt-1 text-xs text-zinc-600">
                          {entry.reflection.recurringThemes.slice(0, 3).join(" · ")}
                        </p>
                      ) : null}
                    </Link>
                  ))}
                  {sorted.length > 12 ? (
                    <Button asChild variant="ghost" size="sm" className="w-full">
                      <Link href="/journal">View all reflections</Link>
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
