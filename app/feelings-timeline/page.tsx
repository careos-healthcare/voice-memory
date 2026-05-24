"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildSoftEmotionalTimelineReport } from "@/lib/personalization/soft-emotional-timeline";
import {
  getEmotionalTerritoryById,
  listEmotionalTerritories,
} from "@/lib/territories/emotional-territories";
import { resolveTerritoryLabel } from "@/lib/territories/territory-preferences";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { SoftEmotionalTimelineReport } from "@/types/personalization";
import type { EmotionalTerritory } from "@/types/emotional-territory";

const BAND_CLASS: Record<
  SoftEmotionalTimelineReport["segments"][number]["intensityBand"],
  string
> = {
  quiet: "bg-zinc-600/20",
  steady: "bg-violet-500/15",
  heavy: "bg-zinc-500/25",
  mixed: "bg-zinc-600/15",
};

function FeelingsTimelineContent() {
  const searchParams = useSearchParams();
  const territoryParam = searchParams.get("territory");
  const [report, setReport] = useState<SoftEmotionalTimelineReport | null>(null);
  const [territories, setTerritories] = useState<EmotionalTerritory[]>([]);
  const [activeTerritoryId, setActiveTerritoryId] = useState<string | null>(
    territoryParam,
  );

  useEffect(() => {
    setActiveTerritoryId(territoryParam);
  }, [territoryParam]);

  useEffect(() => {
    const entries = getMemoryEligibleEntries();
    setTerritories(listEmotionalTerritories(entries));
    setReport(buildSoftEmotionalTimelineReport(entries, activeTerritoryId));
  }, [activeTerritoryId]);

  const activeTerritory = useMemo(() => {
    if (!activeTerritoryId) return null;
    const found = getEmotionalTerritoryById(getMemoryEligibleEntries(), activeTerritoryId);
    if (!found) return null;
    return {
      ...found,
      label: resolveTerritoryLabel(found.id, found.defaultLabel),
    };
  }, [activeTerritoryId]);

  return (
    <div className="min-h-screen bg-background">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <header className="mt-6 space-y-3">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Optional view</p>
          <h1 className="text-2xl font-normal tracking-tight text-foreground sm:text-3xl">
            How this has felt over time
          </h1>
          <p className="max-w-xl text-sm leading-relaxed text-zinc-500">
            A quiet read of movement across weeks — not a chart wall, not a score, not a diagnosis.
          </p>
          {activeTerritory ? (
            <p className="text-sm text-zinc-400">
              In context: {activeTerritory.label}
            </p>
          ) : null}
        </header>

        {territories.length > 0 ? (
          <div className="mt-8 flex flex-wrap gap-2">
            <Link
              href="/feelings-timeline"
              className={`rounded-full px-3 py-1 text-xs ${
                !activeTerritoryId
                  ? "bg-white/[0.08] text-zinc-300"
                  : "text-zinc-600 hover:text-zinc-400"
              }`}
            >
              All reflections
            </Link>
            {territories.map((territory) => (
              <Link
                key={territory.id}
                href={`/feelings-timeline?territory=${encodeURIComponent(territory.id)}`}
                className={`rounded-full px-3 py-1 text-xs ${
                  activeTerritoryId === territory.id
                    ? "bg-white/[0.08] text-zinc-300"
                    : "text-zinc-600 hover:text-zinc-400"
                }`}
              >
                {resolveTerritoryLabel(territory.id, territory.defaultLabel)}
              </Link>
            ))}
          </div>
        ) : null}

        <div className="mt-14 space-y-8">
          {!report ? (
            <p className="text-sm text-zinc-600">One moment…</p>
          ) : report.segments.length === 0 ? (
            <div className="py-16 text-center">
              <p className="text-sm text-zinc-500">
                {activeTerritory
                  ? "Not enough reflections in this context yet."
                  : "Not enough reflections yet for a gentle timeline."}
              </p>
              <Button asChild className="mt-6" variant="secondary">
                <Link href="/">Record a reflection</Link>
              </Button>
            </div>
          ) : (
            <ul className="space-y-6">
              {report.segments.map((segment) => (
                <li
                  key={segment.id}
                  className="rounded-xl border border-white/[0.06] px-4 py-4 sm:px-5"
                >
                  <div className="flex items-start gap-4">
                    <div
                      className={`mt-1 h-10 w-1 shrink-0 rounded-full ${BAND_CLASS[segment.intensityBand]}`}
                      aria-hidden
                    />
                    <div className="space-y-1">
                      <p className="text-sm text-zinc-500">{segment.periodLabel}</p>
                      <p className="text-base font-normal leading-relaxed text-zinc-300">
                        {segment.feelingLine}
                      </p>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="mt-12 flex flex-wrap gap-3 text-sm">
          <Link href="/territories" className="text-violet-300 hover:text-violet-200">
            Emotional territories →
          </Link>
          <Link href="/timeline" className="text-violet-300 hover:text-violet-200">
            Full timeline →
          </Link>
          <Link href="/settings" className="text-zinc-500 hover:text-zinc-300">
            Personalization →
          </Link>
        </div>
      </div>
    </div>
  );
}

export default function FeelingsTimelinePage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-background">
          <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
            <SiteHeader />
            <p className="mt-20 text-sm text-zinc-600">One moment…</p>
          </div>
        </div>
      }
    >
      <FeelingsTimelineContent />
    </Suspense>
  );
}
