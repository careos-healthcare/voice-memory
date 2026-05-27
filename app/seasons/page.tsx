"use client";

import { useEffect, useState } from "react";
import { Leaf } from "lucide-react";

import { MemorySeasonOverview } from "@/components/memory/MemorySeasonSection";
import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { MotionPageTitle } from "@/components/motion/MotionPage";
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

        <MotionPageTitle title="Over the year" />

        <div className="mt-20 space-y-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">One moment…</p>
          ) : !seasons || seasons.length === 0 ? (
            <AnticipatoryEmptyState icon={<Leaf className="h-6 w-6 text-violet-300" />} />
          ) : (
            <MemorySeasonOverview
              calendarSeasons={calendarSeasons}
              monthlyPeriods={monthlyPeriods}
            />
          )}
        </div>
      </div>
    </div>
  );
}
