"use client";

import { useMemo } from "react";

import { buildArchiveHomeScoreView } from "@/lib/archive/archive-home-score";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveHomeScoreProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveHomeScore({ entriesOverride, className = "" }: ArchiveHomeScoreProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveHomeScoreView(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-violet-500/35 bg-gradient-to-br from-violet-950/50 via-zinc-950/90 to-zinc-950 px-4 py-4 font-mono text-sm",
        className,
      )}
      data-testid="archive-home-score"
    >
      <p className="text-[10px] uppercase tracking-[0.25em] text-violet-300/90">Your archive</p>

      <dl className="mt-3 grid gap-2 sm:grid-cols-2">
        <div className="sm:col-span-2">
          <dt className="text-[10px] uppercase text-zinc-600">Current belief</dt>
          <dd className="mt-0.5 text-base font-medium leading-snug text-zinc-50">
            {view.currentBelief}
          </dd>
        </div>
        <div>
          <dt className="text-[10px] uppercase text-zinc-600">Reputation</dt>
          <dd className="mt-0.5 text-zinc-200">{view.reputationLabel}</dd>
        </div>
        <div>
          <dt className="text-[10px] uppercase text-zinc-600">Days tracked</dt>
          <dd className="mt-0.5 tabular-nums text-zinc-200">{view.daysTracked}</dd>
        </div>
        <div>
          <dt className="text-[10px] uppercase text-zinc-600">Evidence</dt>
          <dd className="mt-0.5 tabular-nums text-zinc-200">{view.evidenceCount}</dd>
        </div>
        <div>
          <dt className="text-[10px] uppercase text-zinc-600">Status</dt>
          <dd className="mt-0.5 text-zinc-200">{view.statusLabel}</dd>
        </div>
        <div className="sm:col-span-2">
          <dt className="text-[10px] uppercase text-zinc-600">What changed</dt>
          <dd className="mt-0.5 text-zinc-400">{view.whatChangedOneLine}</dd>
        </div>
      </dl>
    </section>
  );
}
