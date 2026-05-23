"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { CalendarDays } from "lucide-react";

import { WhatChangedCard } from "@/components/patterns/WhatChangedCard";
import {
  ContinuityCallbacks,
  MemoryLandmarksStrip,
} from "@/components/patterns/ContinuityCallbacks";
import { CalmUnderstandingCard } from "@/components/patterns/CalmUnderstandingCard";
import { SeeMorePanel } from "@/components/patterns/SeeMorePanel";
import { LongitudinalContinuityCard } from "@/components/patterns/LongitudinalContinuityCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { getMonthlyReflection } from "@/lib/patterns/calmness";
import { getChangesForMonthly } from "@/lib/patterns/changes";
import { getContinuityForMonthly } from "@/lib/patterns/continuity-moments";
import { buildContinuityReport } from "@/lib/patterns/continuity-engine";
import { getAllEntries } from "@/lib/storage";
import type { CalmnessReport } from "@/types/calmness";
import type { ChangeDetectionReport } from "@/types/changes";
import type { ContinuityMomentsReport } from "@/types/continuity-moments";
import type { ContinuityReport } from "@/types/continuity";

export default function MonthlyPage() {
  const { quiet, limits } = useQuietMode();
  const [calm, setCalm] = useState<CalmnessReport | null>(null);
  const [changes, setChanges] = useState<ChangeDetectionReport | null>(null);
  const [continuityMoments, setContinuityMoments] = useState<ContinuityMomentsReport | null>(null);
  const [continuity, setContinuity] = useState<ContinuityReport | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setCalm(getMonthlyReflection(entries));
      setChanges(getChangesForMonthly(entries, limits.changes));
      setContinuityMoments(getContinuityForMonthly(entries, limits));
      setContinuity(buildContinuityReport(entries, { scope: "archive", limit: 6 }));
    });
    return () => cancelAnimationFrame(id);
  }, [limits.changes, limits.callbacks, limits.landmarks]);

  const loading = calm === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Monthly</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">This month</h1>
          <p className="mt-3 max-w-lg text-sm leading-relaxed text-zinc-500">
            How your language shifted — what became calmer, what faded, what returned.
            Orientation, not evaluation.
          </p>
        </motion.div>

        <div className={quiet ? "mt-12 space-y-16" : "mt-12 space-y-12"}>
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading your archive…
              </CardContent>
            </Card>
          ) : !calm?.hasData && !changes?.hasData && !continuityMoments?.hasData ? (
            <Card className="border-dashed border-white/5">
              <CardContent className="px-6 py-16 text-center">
                <CalendarDays className="mx-auto h-8 w-8 text-zinc-600" />
                <p className="mt-4 text-lg font-medium text-zinc-300">Not enough for a monthly read yet</p>
                <p className="mt-2 text-sm text-zinc-600">
                  A few more reflections will show how your language evolves across weeks.
                </p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/">Record a reflection</Link>
                </Button>
              </CardContent>
            </Card>
          ) : (
            <>
              <WhatChangedCard
                report={
                  changes ?? {
                    changes: [],
                    hasData: false,
                    scope: "monthly",
                    generatedAt: "",
                  }
                }
                subtitle="Last 30 days"
                quiet={quiet}
              />

              {continuityMoments?.callbacks.length ? (
                <ContinuityCallbacks
                  callbacks={continuityMoments.callbacks}
                  title="What became clearer"
                  quiet={quiet}
                />
              ) : null}

              {continuityMoments?.landmarks.length ? (
                <MemoryLandmarksStrip landmarks={continuityMoments.landmarks} quiet={quiet} />
              ) : null}

              {!changes?.hasData && calm?.hasData ? (
                <CalmUnderstandingCard
                  report={calm}
                  title="What changed"
                  subtitle="Last 30 days"
                  showLandmarks
                />
              ) : null}

              {!quiet && (continuity?.hasData || (changes?.hasData && calm?.hasData)) ? (
                <SeeMorePanel label="See continuity details">
                  {changes?.hasData && calm?.hasData ? (
                    <CalmUnderstandingCard report={calm} title="Further context" showLandmarks />
                  ) : null}
                  {continuity?.hasData ? (
                    <LongitudinalContinuityCard
                      report={continuity}
                      title="Threads across the month"
                      subtitle=""
                      maxItems={4}
                      showSummaries
                      showArcs={false}
                      showIdentity={false}
                    />
                  ) : null}
                </SeeMorePanel>
              ) : null}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
