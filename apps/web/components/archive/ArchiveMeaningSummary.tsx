"use client";

import { useMemo } from "react";

import { ArchiveTransition } from "@/components/archive/ArchiveTransition";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveMeaningSummary } from "@/lib/archive/archive-meaning-summary";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveMeaningSummaryProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

/**
 * Single human sentence after belief, timeline, and evidence in the command center.
 */
export function ArchiveMeaningSummary({
  entriesOverride,
  className = "",
}: ArchiveMeaningSummaryProps) {
  const hydrated = useClientHydrated();

  const sentence = useMemo(() => {
    if (!hydrated) return null;
    const belief = buildArchiveBeliefView(entriesOverride);
    if (!belief) return null;
    return buildArchiveMeaningSummary(belief);
  }, [hydrated, entriesOverride]);

  if (!sentence) return null;

  return (
    <ArchiveTransition mode="fade" motionKey={sentence} className={className}>
      <p
        className={cn(
          ARCHIVE_TYPO.body,
          "border-t border-white/10 pt-4 text-base leading-relaxed text-zinc-300 italic",
          ARCHIVE_SPACE.sm,
        )}
        data-testid="archive-meaning-summary"
        data-archive-section="meaning"
      >
        {sentence}
      </p>
    </ArchiveTransition>
  );
}
