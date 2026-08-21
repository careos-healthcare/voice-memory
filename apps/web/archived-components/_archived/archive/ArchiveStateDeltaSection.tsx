"use client";

import { useEffect, useMemo } from "react";

import { ArchiveStateDeltaCard } from "@/archived-components/_archived/archive/ArchiveStateDeltaCard";
import { ARCHIVE_DELTA_FIRST_VISIT } from "@/lib/archive/archive-state-delta-copy";
import {
  buildArchiveStateDelta,
  commitArchiveStateView,
} from "@/lib/archive/archive-state-snapshot";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

type ArchiveStateDeltaSectionProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

/** Archive home — delta directly under current belief. */
export function ArchiveStateDeltaSection({
  entriesOverride,
  className = "",
}: ArchiveStateDeltaSectionProps) {
  const hydrated = useClientHydrated();
  const entries = entriesOverride ?? getMemoryEligibleEntries();

  const delta = useMemo(
    () => (hydrated ? buildArchiveStateDelta(entries) : null),
    [hydrated, entries],
  );

  useEffect(() => {
    if (!hydrated) return;
    return () => {
      commitArchiveStateView(entries);
    };
  }, [hydrated, entries]);

  if (!delta) return null;
  if (
    !delta.hasChanges &&
    !delta.awayReturn &&
    delta.subheadline === ARCHIVE_DELTA_FIRST_VISIT
  ) {
    return null;
  }

  return (
    <ArchiveStateDeltaCard
      delta={delta}
      className={className}
      prominent={delta.awayReturn || delta.hasChanges}
    />
  );
}
