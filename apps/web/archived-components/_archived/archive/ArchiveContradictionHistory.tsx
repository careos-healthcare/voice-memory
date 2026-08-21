"use client";

import { useMemo } from "react";

import { ArchiveBeliefEvidenceSection } from "@/archived-components/_archived/archive/ArchiveBeliefEvidenceSection";
import { ArchiveTransition } from "@/archived-components/_archived/archive/ArchiveTransition";
import { BeliefChangeTimeline } from "@/archived-components/_archived/archive/BeliefChangeTimeline";
import {
  buildContradictionHistoryView,
  CONTRADICTION_HISTORY_TITLE,
} from "@/lib/archive/contradiction-history";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveContradictionHistoryProps = {
  entriesOverride?: JournalEntry[];
  theoryId?: string;
  className?: string;
  titleOverride?: string;
};

export function ArchiveContradictionHistory({
  entriesOverride,
  theoryId,
  className = "",
  titleOverride,
}: ArchiveContradictionHistoryProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildContradictionHistoryView(
      entries,
      theoryId ? { theoryId } : undefined,
    );
  }, [hydrated, entriesOverride, theoryId]);

  if (!view) return null;

  return (
    <ArchiveTransition mode="card" testId="archive-contradiction-history-wrap">
      <section
        className={cn(
          "rounded-2xl border border-amber-500/20 bg-gradient-to-b from-amber-950/20 to-zinc-950/80 px-4 py-4",
          className,
        )}
        data-testid="archive-contradiction-history"
        data-section="contradiction-history"
      >
        <p className={ARCHIVE_TYPO.eyebrow}>{titleOverride ?? CONTRADICTION_HISTORY_TITLE}</p>
        <p className="mt-2 text-sm font-medium leading-relaxed text-zinc-200">
          {view.headline}
        </p>

        <div className="mt-4 space-y-4">
          <div>
            <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
              Previous belief
            </h3>
            <p className="mt-1 text-sm leading-relaxed text-zinc-400">{view.previousBelief}</p>
          </div>

          <div>
            <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
              Current belief
            </h3>
            <p className="mt-1 text-sm font-medium leading-relaxed text-zinc-100">
              {view.currentBelief}
            </p>
          </div>

          <div>
            <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
              Supporting evidence
            </h3>
            <div className="mt-2 max-h-40 overflow-y-auto">
              <ArchiveBeliefEvidenceSection
                evidence={{
                  ...view.evidence,
                  contradictingQuotes: [],
                  costEvidenceLines: [],
                  predictionFailureLines: [],
                }}
              />
            </div>
          </div>

          <div>
            <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
              Timeline
            </h3>
            <BeliefChangeTimeline
              className="mt-2"
              entriesOverride={entriesOverride}
              theoryId={view.theoryId}
            />
          </div>

          <div className="border-t border-white/10 pt-4">
            <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
              Archive explanation
            </h3>
            <p className={`${ARCHIVE_TYPO.body} mt-2 text-zinc-400`}>{view.archiveExplanation}</p>
          </div>
        </div>
      </section>
    </ArchiveTransition>
  );
}
