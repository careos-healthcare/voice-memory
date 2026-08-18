"use client";

import { useMemo } from "react";

import { ARCHIVE_LATEST_MILESTONE_LABEL } from "@/lib/archive/archive-milestone-copy";
import { buildArchiveMilestones } from "@/lib/archive/archive-milestones";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveLatestMilestoneProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveLatestMilestone({
  entriesOverride,
  className = "",
}: ArchiveLatestMilestoneProps) {
  const hydrated = useClientHydrated();
  const view = useMemo(
    () => (hydrated ? buildArchiveMilestones(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!view?.latest) return null;

  const { latest } = view;

  return (
    <section
      className={cn(
        "rounded-2xl border border-sky-500/25 bg-sky-950/20 px-4 py-4",
        className,
      )}
      data-testid="archive-latest-milestone"
    >
      <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-sky-300/80">
        {ARCHIVE_LATEST_MILESTONE_LABEL}
      </p>
      <h2 className={`${ARCHIVE_TYPO.sectionTitle} mt-2`}>{latest.title}</h2>
      <p className={`${ARCHIVE_TYPO.body} mt-2 text-zinc-200`}>
        {latest.type === "ARCHIVE_CHANGED_ITS_MIND"
          ? "A previously strong belief weakened after contradictory evidence."
          : latest.explanation}
      </p>
    </section>
  );
}
