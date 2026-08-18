"use client";

import { useMemo } from "react";

import { buildFirstSessionValueView } from "@/lib/archive/first-session-value";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type FirstSessionValueCardProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function FirstSessionValueCard({
  entriesOverride,
  className = "",
}: FirstSessionValueCardProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildFirstSessionValueView(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-emerald-500/25 bg-emerald-950/15 px-4 py-4 text-left",
        className,
      )}
      data-testid="first-session-value-card"
    >
      <p className="text-sm font-medium text-emerald-100/95">This reflection created:</p>
      <p className="mt-2 text-sm text-zinc-300">+ {view.evidenceAdded} piece of evidence</p>

      <p className="mt-4 text-sm font-medium text-zinc-300">The archive now has:</p>
      <p className="mt-1 text-sm text-zinc-400">{view.observationLabel}</p>

      <p className="mt-4 text-sm font-medium text-zinc-300">Next milestone:</p>
      <p className="mt-1 text-sm leading-relaxed text-zinc-500">{view.nextMilestone}</p>
    </section>
  );
}
