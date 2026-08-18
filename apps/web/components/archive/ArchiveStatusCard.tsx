"use client";

import { useMemo } from "react";

import { buildArchiveStatusView } from "@/lib/archive/archive-status";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveStatusCardProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveStatusCard({ entriesOverride, className }: ArchiveStatusCardProps) {
  const hydrated = useClientHydrated();
  const view = useMemo(
    () => (hydrated ? buildArchiveStatusView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!view) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-violet-500/20 bg-violet-950/20 px-4 py-4",
        className,
      )}
      data-testid="archive-status-card"
      data-archive-living-status={view.status}
    >
      <p className={ARCHIVE_TYPO.eyebrow}>{view.title}</p>
      <p className={cn(ARCHIVE_TYPO.pageTitle, "mt-1 text-lg")}>{view.label}</p>
      <p className={cn(ARCHIVE_TYPO.body, "mt-2")}>{view.line}</p>
    </section>
  );
}
