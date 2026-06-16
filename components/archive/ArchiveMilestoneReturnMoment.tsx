"use client";

import { useEffect, useMemo, useState } from "react";

import {
  ARCHIVE_MILESTONE_RETURN_EYEBROW,
  ARCHIVE_MILESTONE_RETURN_HEADLINE,
} from "@/lib/archive/archive-milestone-copy";
import {
  dismissArchiveMilestoneReturn,
  pickUnacknowledgedMilestone,
} from "@/lib/archive/archive-milestone-return";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveMilestoneReturnMomentProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveMilestoneReturnMoment({
  entriesOverride,
  className = "",
}: ArchiveMilestoneReturnMomentProps) {
  const hydrated = useClientHydrated();
  const [dismissed, setDismissed] = useState(false);

  const milestone = useMemo(
    () => (hydrated && !dismissed ? pickUnacknowledgedMilestone(entriesOverride) : null),
    [hydrated, dismissed, entriesOverride],
  );

  useEffect(() => {
    if (!hydrated) return;
    setDismissed(false);
  }, [hydrated, entriesOverride]);

  if (!milestone) return null;

  const dismiss = () => {
    dismissArchiveMilestoneReturn();
    setDismissed(true);
  };

  return (
    <section
      className={cn(
        "rounded-2xl border border-violet-500/30 bg-violet-950/25 px-4 py-4",
        className,
      )}
      data-testid="archive-milestone-return-moment"
    >
      <p className="font-mono text-[10px] uppercase tracking-[0.22em] text-violet-300/90">
        {ARCHIVE_MILESTONE_RETURN_EYEBROW}
      </p>
      <h2 className="mt-2 text-sm font-medium text-violet-100">
        {ARCHIVE_MILESTONE_RETURN_HEADLINE}
      </h2>
      <p className="mt-2 text-sm leading-relaxed text-zinc-300">{milestone.explanation}</p>
      <p className="mt-1 text-xs text-zinc-500">{milestone.title}</p>
      <button
        type="button"
        onClick={dismiss}
        className="mt-3 text-xs text-zinc-600 hover:text-zinc-400"
      >
        Dismiss
      </button>
    </section>
  );
}
