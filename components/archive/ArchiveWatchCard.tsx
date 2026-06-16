"use client";

import { ARCHIVE_V3_WHAT_TO_WATCH } from "@/lib/archive/archive-reduction-v3-copy";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { cn } from "@/lib/utils";

type ArchiveWatchCardProps = {
  watchItem: string;
  className?: string;
};

/** Single-sentence watch line — no dashboards. */
export function ArchiveWatchCard({ watchItem, className = "" }: ArchiveWatchCardProps) {
  return (
    <section
      className={cn(
        "rounded-2xl border border-amber-500/25 bg-amber-950/20 px-4 py-4",
        className,
      )}
      data-testid="archive-watch-card"
    >
      <h2 className={ARCHIVE_TYPO.sectionTitle}>{ARCHIVE_V3_WHAT_TO_WATCH}</h2>
      <p className={`${ARCHIVE_TYPO.body} mt-2 text-zinc-200`}>{watchItem}</p>
    </section>
  );
}
