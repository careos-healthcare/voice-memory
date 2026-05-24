"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { MapPin } from "lucide-react";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { SiteHeader } from "@/components/SiteHeader";
import { TerritoryList } from "@/components/territories/TerritorySections";
import { Button } from "@/components/ui/button";
import { listEmotionalTerritories } from "@/lib/territories/emotional-territories";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { EmotionalTerritory } from "@/types/emotional-territory";

export default function TerritoriesPage() {
  const [territories, setTerritories] = useState<EmotionalTerritory[] | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getMemoryEligibleEntries();
      setTerritories(listEmotionalTerritories(entries));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = territories === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <header className="mt-6 space-y-3">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Life context</p>
          <h1 className="text-2xl font-normal tracking-tight text-white sm:text-3xl">
            Emotional territories
          </h1>
          <p className="max-w-xl text-sm leading-relaxed text-zinc-500">
            Soft places your reflections gather — not mood categories, not labels, not a chart wall.
          </p>
        </header>

        <div className="mt-14">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">One moment…</p>
          ) : territories.length === 0 ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <MapPin className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">
                  No territories yet
                </p>
                <p className="mt-2 text-sm text-zinc-600">
                  These emerge when the same life context shows up more than once.
                </p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/">Start recording</Link>
                </Button>
              </div>
            </>
          ) : (
            <TerritoryList territories={territories} />
          )}
        </div>

        <div className="mt-12 flex flex-wrap gap-3 text-sm">
          <Link href="/feelings-timeline" className="text-violet-300 hover:text-violet-200">
            Feelings timeline →
          </Link>
          <Link href="/threads" className="text-zinc-500 hover:text-zinc-300">
            Threads →
          </Link>
        </div>
      </div>
    </div>
  );
}
