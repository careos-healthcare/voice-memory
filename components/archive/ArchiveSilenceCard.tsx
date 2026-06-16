"use client";

import { useMemo } from "react";

import { ArchiveTransition } from "@/components/archive/ArchiveTransition";
import {
  ARCHIVE_SILENCE_TITLE,
  buildArchiveSilenceView,
} from "@/lib/archive/archive-silence";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveSilenceCardProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveSilenceCard({
  entriesOverride,
  className = "",
}: ArchiveSilenceCardProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveSilenceView(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <ArchiveTransition mode="card" testId="archive-silence-card-wrap">
      <section
        className={cn(
          "rounded-2xl border border-zinc-600/30 bg-zinc-950/70 px-4 py-4",
          className,
        )}
        data-testid="archive-silence-card"
        data-section="archive-silence"
      >
        <p className={ARCHIVE_TYPO.eyebrow}>{ARCHIVE_SILENCE_TITLE}</p>
        <ul className={`${ARCHIVE_TYPO.body} mt-3 space-y-2`}>
          {view.signals.map((signal) => (
            <li key={signal.id} data-archive-silence-kind={signal.kind}>
              {signal.text}
            </li>
          ))}
        </ul>
      </section>
    </ArchiveTransition>
  );
}
