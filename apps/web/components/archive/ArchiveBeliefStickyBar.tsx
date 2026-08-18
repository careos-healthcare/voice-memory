"use client";

import { useMemo } from "react";

import { ArchiveAnimatedConfidence } from "@/components/archive/ArchiveTransition";
import { buildArchiveBeliefObject } from "@/lib/archive/build-archive-belief-object";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveBeliefStickyBarProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

/** Always-visible belief strip — belief, confidence, status. */
export function ArchiveBeliefStickyBar({
  entriesOverride,
  className = "",
}: ArchiveBeliefStickyBarProps) {
  const hydrated = useClientHydrated();

  const beliefObject = useMemo(() => {
    if (!hydrated) return null;
    return buildArchiveBeliefObject(entriesOverride ?? getMemoryEligibleEntries());
  }, [hydrated, entriesOverride]);

  if (!beliefObject) return null;

  const trustLine = beliefObject.trustReasons[0] ?? beliefObject.reputation;
  const changeLine = beliefObject.whatChanged[0] ?? "No change lines yet.";

  return (
    <div
      className={cn(
        "sticky top-0 z-30 -mx-4 border-b border-violet-500/35 bg-zinc-950/95 px-4 py-2.5 backdrop-blur-md sm:-mx-6 sm:px-6",
        className,
      )}
      data-testid="archive-belief-sticky-bar"
      role="region"
      aria-label="Current archive belief"
    >
      <p className="line-clamp-2 text-sm font-medium leading-snug text-zinc-100">
        {beliefObject.belief}
      </p>
      <dl className="mt-1.5 flex flex-wrap gap-x-4 gap-y-0.5 font-mono text-[11px] text-zinc-400">
        <div className="flex items-baseline gap-1.5">
          <dt className="uppercase tracking-wider text-zinc-600">Confidence</dt>
          <dd className="tabular-nums text-zinc-300">
            <ArchiveAnimatedConfidence value={beliefObject.confidence} />
          </dd>
        </div>
        <div className="flex items-baseline gap-1.5">
          <dt className="uppercase tracking-wider text-zinc-600">Status</dt>
          <dd className="text-zinc-300">{beliefObject.status}</dd>
        </div>
      </dl>
      <p className="mt-1 line-clamp-1 text-[10px] text-zinc-500">
        <span className="uppercase tracking-wider text-zinc-600">Trust</span>{" "}
        <span className="text-zinc-400">{trustLine}</span>
      </p>
      <p className="line-clamp-1 text-[10px] text-zinc-500">
        <span className="uppercase tracking-wider text-zinc-600">Change</span>{" "}
        <span className="text-zinc-400">{changeLine}</span>
      </p>
    </div>
  );
}
