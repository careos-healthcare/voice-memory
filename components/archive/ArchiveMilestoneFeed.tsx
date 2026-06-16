"use client";

import { useMemo } from "react";

import { ARCHIVE_MILESTONE_FEED_HEADLINE } from "@/lib/archive/archive-milestone-copy";
import {
  buildArchiveMilestones,
  recentArchiveMilestones,
} from "@/lib/archive/archive-milestones";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveMilestoneFeedProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveMilestoneFeed({
  entriesOverride,
  className = "",
}: ArchiveMilestoneFeedProps) {
  const hydrated = useClientHydrated();
  const recent = useMemo(() => {
    if (!hydrated) return [];
    const view = buildArchiveMilestones(entriesOverride);
    return recentArchiveMilestones(view, 5);
  }, [hydrated, entriesOverride]);

  if (recent.length === 0) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-white/10 bg-zinc-900/30 px-4 py-4",
        className,
      )}
      data-testid="archive-milestone-feed"
    >
      <h2 className={ARCHIVE_TYPO.sectionTitle}>{ARCHIVE_MILESTONE_FEED_HEADLINE}</h2>
      <ul className="mt-3 space-y-3">
        {recent.map((milestone) => (
          <li
            key={milestone.id}
            className="rounded-xl border border-white/5 bg-black/20 px-3 py-3"
          >
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <p className="text-xs text-zinc-500">{milestone.periodLabel}</p>
            </div>
            <p className={`${ARCHIVE_TYPO.caption} mt-1 font-medium text-zinc-200`}>
              {milestone.title}
            </p>
            <p className="mt-1 text-xs leading-relaxed text-zinc-500">
              {milestone.explanation}
            </p>
          </li>
        ))}
      </ul>
    </section>
  );
}
