"use client";

import { useEffect, useState } from "react";
import { Leaf } from "lucide-react";

import { MemorySeasonOverview } from "@/archived-components/_archived/memory/MemorySeasonSection";
import { AnticipatoryEmptyState } from "@/archived-components/_archived/memory/AnticipatoryEmptyState";
import { MotionPageTitle } from "@/archived-components/_archived/motion/MotionPage";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import {
  calendarSeasonsOnly,
  listMemorySeasons,
  monthlyPeriodsOnly,
} from "@/lib/memory/seasons";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { MemorySeason } from "@/types/memory-season";

export default function SeasonsPage() {
  const [seasons, setSeasons] = useState<MemorySeason[] | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setSeasons(listMemorySeasons(getMemoryEligibleEntries()));
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

        <PrimaryMain>
        <MotionPageTitle title="Over the year" />

        <div className="mt-20 space-y-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-muted" role="status">One moment…</p>
          ) : !seasons || seasons.length === 0 ? (
            <AnticipatoryEmptyState icon={<Leaf className="h-6 w-6 text-violet-300" />} />
          ) : (
            <MemorySeasonOverview
              calendarSeasons={calendarSeasons}
              monthlyPeriods={monthlyPeriods}
            />
          )}
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
