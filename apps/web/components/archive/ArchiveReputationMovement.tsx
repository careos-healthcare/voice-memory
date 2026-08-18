"use client";

import { useMemo } from "react";

import { buildArchiveReputationMovement } from "@/lib/archive/archive-reputation-movement";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveReputationMovementProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveReputationMovement({
  entriesOverride,
  className = "",
}: ArchiveReputationMovementProps) {
  const hydrated = useClientHydrated();

  const movement = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveReputationMovement(entries);
  }, [hydrated, entriesOverride]);

  if (!movement) return null;

  return (
    <div
      className={cn(
        "rounded-2xl border border-violet-500/25 bg-violet-950/25 px-4 py-4",
        className,
      )}
      data-testid="archive-reputation-movement"
    >
      <p className="text-sm font-medium text-zinc-100">{movement.headline}</p>
      {movement.detail ? (
        <p className="mt-1 text-xs leading-relaxed text-zinc-500">{movement.detail}</p>
      ) : null}
    </div>
  );
}
