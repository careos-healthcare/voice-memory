"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";

import { SiteHeader } from "@/components/SiteHeader";
import { TerritoryDetail } from "@/components/territories/TerritorySections";
import { TerritoryRenameControl } from "@/components/territories/TerritoryRenameControl";
import {
  getEmotionalTerritoryBySlug,
} from "@/lib/territories/emotional-territories";
import {
  resolveTerritoryLabel,
  writeActiveTerritoryId,
} from "@/lib/territories/territory-preferences";
import { trackTerritoryOpened } from "@/lib/territories/territory-observation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { EmotionalTerritory } from "@/types/emotional-territory";

export default function TerritoryDetailPage() {
  const params = useParams<{ slug: string }>();
  const slug = params.slug;
  const [territory, setTerritory] = useState<EmotionalTerritory | null | undefined>(undefined);

  const refresh = () => {
    const entries = getMemoryEligibleEntries();
    const found = getEmotionalTerritoryBySlug(entries, slug);
    if (found) {
      setTerritory({
        ...found,
        label: resolveTerritoryLabel(found.id, found.defaultLabel),
      });
    } else {
      setTerritory(null);
    }
  };

  useEffect(() => {
    const id = requestAnimationFrame(refresh);
    return () => cancelAnimationFrame(id);
  }, [slug]);

  useEffect(() => {
    const onPref = () => refresh();
    window.addEventListener("voicememory:territory-preferences", onPref);
    return () => window.removeEventListener("voicememory:territory-preferences", onPref);
  }, [slug]);

  useEffect(() => {
    if (!territory) return;
    trackTerritoryOpened(territory.id, territory.slug);
    writeActiveTerritoryId(territory.id);
    return () => writeActiveTerritoryId(null);
  }, [territory?.id, territory?.slug]);

  const loading = territory === undefined;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <div className="mt-6">
          <Link href="/territories" className="text-sm text-zinc-600 hover:text-zinc-400">
            ← Territories
          </Link>
        </div>

        {loading ? (
          <p className="py-20 text-center text-sm text-zinc-600">One moment…</p>
        ) : !territory ? (
          <div className="py-20 text-center">
            <p className="text-sm text-zinc-500">This territory could not be found.</p>
            <Link href="/territories" className="mt-4 inline-block text-sm text-violet-300">
              Back to territories
            </Link>
          </div>
        ) : (
          <div className="mt-10 space-y-8">
            <TerritoryRenameControl
              territoryId={territory.id}
              currentLabel={territory.label}
              defaultLabel={territory.defaultLabel}
            />
            <TerritoryDetail territory={territory} />
          </div>
        )}
      </div>
    </div>
  );
}
