"use client";

import { useMemo } from "react";

import { buildArchiveHistorySummary } from "@/lib/archive/archive-ownership-v2";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveHistorySummaryProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveHistorySummary({
  entriesOverride,
  className = "",
}: ArchiveHistorySummaryProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveHistorySummary(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <div
      className={cn("space-y-2", className)}
      data-testid="archive-history-summary"
    >
      {view.lines.map((line) => (
        <p key={line} className={ARCHIVE_TYPO.body}>
          {line}
        </p>
      ))}
    </div>
  );
}
