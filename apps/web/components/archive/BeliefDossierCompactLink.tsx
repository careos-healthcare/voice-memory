"use client";

import Link from "next/link";

import { buildBeliefDossier } from "@/lib/archive/belief-dossier";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

interface BeliefDossierCompactLinkProps {
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function BeliefDossierCompactLink({
  className = "",
  entriesOverride,
}: BeliefDossierCompactLinkProps) {
  const hydrated = useClientHydrated();
  if (!hydrated) return null;

  const dossier = buildBeliefDossier(entriesOverride);
  if (!dossier) return null;

  return (
    <div
      className={`rounded-xl border border-white/10 bg-zinc-900/40 px-4 py-3 ${className}`}
      data-testid="belief-dossier-compact-link"
    >
      <p className="text-xs text-zinc-500">Current case file</p>
      <p className="mt-1 line-clamp-2 text-sm text-zinc-300">{dossier.belief}</p>
      <Link
        href="/archive-belief#belief-dossier"
        className="mt-2 inline-flex text-sm font-medium text-violet-300 hover:text-violet-200"
      >
        Open belief dossier →
      </Link>
    </div>
  );
}
