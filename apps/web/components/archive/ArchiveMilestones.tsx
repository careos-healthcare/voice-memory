"use client";

import { useMemo } from "react";

import { buildArchiveMilestones } from "@/lib/archive/archive-ownership-v2";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveMilestonesProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveMilestones({ entriesOverride, className = "" }: ArchiveMilestonesProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveMilestones(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <div className={cn(className)} data-testid="archive-milestones">
      <p className={ARCHIVE_TYPO.body}>{view.headline}</p>
      <ul className={`${ARCHIVE_TYPO.body} mt-2 space-y-1`}>
        {view.items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </div>
  );
}
