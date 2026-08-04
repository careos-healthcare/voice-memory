"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { MapPin } from "lucide-react";

import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
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

        <PrimaryMain className="mt-6">
        <header className="space-y-3">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-200">Life context</p>
          <h1 className="text-2xl font-normal tracking-tight text-white sm:text-3xl">
            Emotional territories
          </h1>
          <p className="max-w-xl text-sm leading-relaxed text-muted">
            Soft places your moments gather — not mood categories, not labels, not a chart wall.
          </p>
        </header>

        <div className="mt-14">
          {loading ? (
            <p className="py-20 text-center text-sm text-muted" role="status">One moment…</p>
          ) : territories.length === 0 ? (
            <AnticipatoryEmptyState icon={<MapPin className="h-6 w-6 text-violet-300" />} />
          ) : (
            <TerritoryList territories={territories} />
          )}
        </div>

        <div className="mt-12 flex flex-wrap gap-3 text-sm">
          <Link href="/feelings-timeline" className="text-violet-300 hover:text-violet-200">
            Feelings timeline →
          </Link>
          <Link href="/threads" className="text-muted hover:text-zinc-200">
            Threads →
          </Link>
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
