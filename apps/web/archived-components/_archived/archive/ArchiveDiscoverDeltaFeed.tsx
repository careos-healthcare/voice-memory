"use client";

import { useEffect, useMemo } from "react";

import { ArchiveStateDeltaCard } from "@/archived-components/_archived/archive/ArchiveStateDeltaCard";
import { ArchiveEmptyState } from "@/archived-components/_archived/archive/ArchiveEmptyState";
import {
  buildArchiveDiscoverDeltaCollection,
  commitArchiveStateView,
} from "@/lib/archive/archive-state-snapshot";
import { ARCHIVE_DELTA_NO_CHANGES } from "@/lib/archive/archive-state-delta-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

type ArchiveDiscoverDeltaFeedProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

/** Legacy delta collection — prefer ArchiveActivityPanel on discover. */
export function ArchiveDiscoverDeltaFeed({
  entriesOverride,
  className = "",
}: ArchiveDiscoverDeltaFeedProps) {
  const hydrated = useClientHydrated();
  const entries = entriesOverride ?? getMemoryEligibleEntries();

  const deltas = useMemo(
    () => (hydrated ? buildArchiveDiscoverDeltaCollection(entries) : []),
    [hydrated, entries],
  );

  useEffect(() => {
    if (!hydrated) return;
    return () => {
      commitArchiveStateView(entries);
    };
  }, [hydrated, entries]);

  if (!hydrated) return null;

  const withChanges = deltas.filter((d) => d.hasChanges);

  if (withChanges.length === 0) {
    return (
      <ArchiveEmptyState
        className={className}
        title="No archive changes yet"
        body={ARCHIVE_DELTA_NO_CHANGES}
        testId="archive-discover-delta-empty"
      />
    );
  }

  return (
    <div className={`space-y-4 ${className}`} data-testid="archive-discover-delta-feed">
      {withChanges.map((delta, index) => (
        <ArchiveStateDeltaCard
          key={`${delta.generatedAt}-${index}`}
          delta={delta}
          prominent={index === 0}
        />
      ))}
    </div>
  );
}
