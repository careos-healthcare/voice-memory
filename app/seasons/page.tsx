"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Leaf } from "lucide-react";

import { MemorySeasonOverview } from "@/components/memory/MemorySeasonSection";
import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import {
  calendarSeasonsOnly,
  listMemorySeasons,
  MEMORY_SEASON_COPY_EXAMPLES,
  monthlyPeriodsOnly,
} from "@/lib/memory/seasons";
import { getAllEntries } from "@/lib/storage";
import type { MemorySeason } from "@/types/memory-season";

export default function SeasonsPage() {
  const [seasons, setSeasons] = useState<MemorySeason[] | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setSeasons(listMemorySeasons(getAllEntries()));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = seasons === null;
  const calendarSeasons = seasons ? calendarSeasonsOnly(seasons) : [];
  const monthlyPeriods = seasons ? monthlyPeriodsOnly(seasons) : [];

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <MotionPageTitle eyebrow="Seasons" title="Memory over time" />

        <p className="mt-4 text-sm leading-relaxed text-zinc-500">
          Your archive grouped by seasons and months — how periods sounded, what
          returned, and what faded.
        </p>

        <div className="mt-20 space-y-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">Reading your archive…</p>
          ) : !seasons || seasons.length === 0 ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <Leaf className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">
                  No seasons yet
                </p>
                <p className="mt-2 text-sm text-zinc-600">
                  Seasons appear once you have a few reflections spread across time.
                </p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/">Start recording</Link>
                </Button>
              </div>
            </>
          ) : (
            <>
              <MemorySeasonOverview
                calendarSeasons={calendarSeasons}
                monthlyPeriods={monthlyPeriods}
              />

              <section className="space-y-4 border-t border-white/5 pt-16">
                <h2 className="text-xs font-normal tracking-wide text-zinc-600">
                  Example copy
                </h2>
                <ul className="space-y-3">
                  {MEMORY_SEASON_COPY_EXAMPLES.map((example) => (
                    <li
                      key={example.kind}
                      className="rounded-2xl border border-white/10 bg-white/[0.02] p-4"
                    >
                      <p className="text-sm font-normal text-zinc-400">
                        &ldquo;{example.message}&rdquo;
                      </p>
                      <p className="mt-2 text-xs leading-relaxed text-zinc-600">
                        {example.whenShown}
                      </p>
                    </li>
                  ))}
                </ul>
              </section>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
