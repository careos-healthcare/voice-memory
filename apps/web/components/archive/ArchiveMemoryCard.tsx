"use client";

import { useMemo } from "react";

import { buildArchiveMemory } from "@/lib/archive/archive-memory";
import { ARCHIVE_MEMORY_TITLE } from "@/lib/archive/living-archive-copy";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveMemoryCardProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveMemoryCard({ entriesOverride, className }: ArchiveMemoryCardProps) {
  const hydrated = useClientHydrated();
  const memory = useMemo(
    () => (hydrated ? buildArchiveMemory(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!memory?.hasEvolution) return null;

  return (
    <section
      className={cn("rounded-2xl border border-white/10 bg-black/25 px-4 py-4", className)}
      data-testid="archive-memory-card"
    >
      <p className={ARCHIVE_TYPO.sectionTitle}>{ARCHIVE_MEMORY_TITLE}</p>
      <div className="mt-4 grid gap-4 sm:grid-cols-3">
        {memory.beats.map((beat) => (
          <div key={beat.label} className="space-y-2">
            <p className="text-xs uppercase tracking-wide text-zinc-500">{beat.label}</p>
            <p className={cn(ARCHIVE_TYPO.body, "text-zinc-300")}>{beat.beliefLine}</p>
            {beat.confidence !== null ? (
              <p className={ARCHIVE_TYPO.caption}>{beat.confidence}% confidence</p>
            ) : null}
          </div>
        ))}
      </div>
    </section>
  );
}
