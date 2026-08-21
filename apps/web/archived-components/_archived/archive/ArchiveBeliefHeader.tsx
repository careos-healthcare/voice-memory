"use client";

import { useMemo } from "react";

import { ArchiveAnimatedConfidence } from "@/archived-components/_archived/archive/ArchiveTransition";
import { buildArchiveBeliefObject } from "@/lib/archive/build-archive-belief-object";
import { ARCHIVE_BELIEF_HEADER_TITLE } from "@/lib/archive/archive-belief-centric-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveBeliefHeaderProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
  compact?: boolean;
};

export function ArchiveBeliefHeader({
  entriesOverride,
  className = "",
  compact = false,
}: ArchiveBeliefHeaderProps) {
  const hydrated = useClientHydrated();

  const beliefObject = useMemo(() => {
    if (!hydrated) return null;
    return buildArchiveBeliefObject(entriesOverride ?? getMemoryEligibleEntries());
  }, [hydrated, entriesOverride]);

  if (!beliefObject) return null;

  return (
    <header
      className={cn(
        "rounded-2xl border border-violet-500/40 bg-gradient-to-br from-violet-950/55 via-zinc-950/90 to-zinc-950 px-4 py-4",
        className,
      )}
      data-testid="archive-belief-header"
      data-surface-first="belief"
    >
      <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-violet-300/90">
        {ARCHIVE_BELIEF_HEADER_TITLE}
      </p>

      <p
        className={cn(
          "mt-3 font-medium leading-snug text-zinc-50",
          compact ? "text-base" : "text-lg sm:text-xl",
        )}
      >
        {beliefObject.belief}
      </p>

      <dl
        className={cn(
          "mt-4 grid gap-3 border-t border-white/10 pt-3",
          compact ? "grid-cols-3 text-xs" : "grid-cols-3 sm:text-sm",
        )}
      >
        <div>
          <dt className="text-[10px] uppercase tracking-wider text-zinc-600">Confidence</dt>
          <dd className="mt-0.5 font-mono tabular-nums text-zinc-200">
            <ArchiveAnimatedConfidence value={beliefObject.confidence} />
          </dd>
        </div>
        <div>
          <dt className="text-[10px] uppercase tracking-wider text-zinc-600">Status</dt>
          <dd className="mt-0.5 text-zinc-300">{beliefObject.status}</dd>
        </div>
        <div className="sr-only" aria-hidden>
          <dt>Internal reputation signal</dt>
          <dd>{beliefObject.reputation}</dd>
        </div>
      </dl>
    </header>
  );
}
