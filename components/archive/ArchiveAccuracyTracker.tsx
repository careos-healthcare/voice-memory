"use client";

import { useMemo } from "react";

import { ArchiveTransition } from "@/components/archive/ArchiveTransition";
import {
  ARCHIVE_ACCURACY_TITLE,
  buildArchiveAccuracyView,
} from "@/lib/archive/archive-accuracy";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { ArchiveBeliefAccuracyStatus } from "@/types/archive-accuracy";
import type { JournalEntry } from "@/types/journal";

const STATUS_STYLES: Record<ArchiveBeliefAccuracyStatus, string> = {
  confirmed: "border-emerald-500/30 bg-emerald-950/30 text-emerald-200",
  challenged: "border-amber-500/30 bg-amber-950/30 text-amber-200",
  unclear: "border-zinc-600/40 bg-zinc-900/50 text-zinc-400",
};

type ArchiveAccuracyTrackerProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
  titleOverride?: string;
};

export function ArchiveAccuracyTracker({
  entriesOverride,
  className = "",
  titleOverride,
}: ArchiveAccuracyTrackerProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveAccuracyView(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <ArchiveTransition mode="card" testId="archive-accuracy-tracker-wrap">
      <section
        className={cn(
          "rounded-2xl border border-white/10 bg-zinc-950/80 px-4 py-4",
          className,
        )}
        data-testid="archive-accuracy-tracker"
        data-section="archive-accuracy"
      >
        <p className={ARCHIVE_TYPO.eyebrow}>{titleOverride ?? ARCHIVE_ACCURACY_TITLE}</p>
        <p className={`${ARCHIVE_TYPO.caption} mt-1`}>
          Measured against later reflections, follow-ups, and outcomes — not proof.
        </p>

        <ul className="mt-4 space-y-3">
          {view.beliefs.map((row) => (
            <li
              key={row.theoryId}
              className="rounded-xl border border-white/5 bg-black/20 px-3 py-3"
              data-archive-accuracy-status={row.status}
            >
              <div className="flex flex-wrap items-start justify-between gap-2">
                <p className="min-w-0 flex-1 text-sm leading-relaxed text-zinc-300 line-clamp-3">
                  {row.belief}
                </p>
                <span
                  className={cn(
                    "shrink-0 rounded-full border px-2.5 py-0.5 text-[10px] font-medium uppercase tracking-wider",
                    STATUS_STYLES[row.status],
                  )}
                >
                  {row.statusLabel}
                </span>
              </div>
              {row.detail ? (
                <p className={`${ARCHIVE_TYPO.caption} mt-2`}>{row.detail}</p>
              ) : null}
            </li>
          ))}
        </ul>
      </section>
    </ArchiveTransition>
  );
}
