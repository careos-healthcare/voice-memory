"use client";

import { useMemo } from "react";

import { buildArchiveCaseFileProgressView } from "@/lib/archive/archive-case-file-progress";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveCaseFileProgressProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveCaseFileProgress({
  entriesOverride,
  className = "",
}: ArchiveCaseFileProgressProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveCaseFileProgressView(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <section
      className={cn("rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4", className)}
      data-testid="archive-case-file-progress"
    >
      <p className={ARCHIVE_TYPO.eyebrow}>{view.title}</p>
      <dl className={`${ARCHIVE_TYPO.body} mt-3 space-y-2`}>
        <div>
          <dt className="text-zinc-600">Evidence</dt>
          <dd className="text-zinc-300">{view.evidenceLabel}</dd>
        </div>
        {view.areasLabel ? (
          <div>
            <dt className="text-zinc-600">Areas</dt>
            <dd className="text-zinc-300">{view.areasLabel}</dd>
          </div>
        ) : null}
        <div>
          <dt className="text-zinc-600">Beliefs</dt>
          <dd className="text-zinc-300">
            {view.beliefsUnderReview} under review
            {view.beliefsStrengthened > 0
              ? ` · ${view.beliefsStrengthened} strengthened`
              : ""}
            {view.beliefsChallenged > 0 ? ` · ${view.beliefsChallenged} challenged` : ""}
          </dd>
        </div>
      </dl>
    </section>
  );
}
