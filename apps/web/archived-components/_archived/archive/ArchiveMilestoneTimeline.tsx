"use client";

import { useMemo } from "react";

import { ARCHIVE_MILESTONE_HISTORY_HEADLINE } from "@/lib/archive/archive-milestone-copy";
import { buildArchiveMilestones } from "@/lib/archive/archive-milestones";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveMilestoneTimelineProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveMilestoneTimeline({
  entriesOverride,
  className = "",
}: ArchiveMilestoneTimelineProps) {
  const hydrated = useClientHydrated();
  const view = useMemo(
    () => (hydrated ? buildArchiveMilestones(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!view || view.milestones.length === 0) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4",
        className,
      )}
      data-testid="archive-milestone-timeline"
    >
      <h2 className={ARCHIVE_TYPO.sectionTitle}>{ARCHIVE_MILESTONE_HISTORY_HEADLINE}</h2>
      <ol className="mt-4 space-y-4">
        {[...view.milestones].reverse().map((milestone) => (
          <li
            key={milestone.id}
            className="border-l border-white/10 pl-4"
            data-testid={`archive-milestone-row-${milestone.type}`}
          >
            <p className="text-xs font-medium text-zinc-500">{milestone.periodLabel}</p>
            <p className={`${ARCHIVE_TYPO.body} mt-1 font-medium text-zinc-100`}>
              {milestone.title}
            </p>
            <p className={`${ARCHIVE_TYPO.caption} mt-1 text-zinc-400`}>
              {milestone.explanation}
            </p>
          </li>
        ))}
      </ol>
    </section>
  );
}
