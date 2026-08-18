"use client";

import { useMemo } from "react";

import { ARCHIVE_CASE_FILE_IMPLICATIONS_HEADLINE } from "@/lib/archive/archive-case-file-copy";
import { buildArchiveImplications } from "@/lib/archive/archive-implications";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveImplicationsCardProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveImplicationsCard({
  entriesOverride,
  className = "",
}: ArchiveImplicationsCardProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(
    () => (hydrated ? buildArchiveImplications(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!view || view.headlineLines.length === 0) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-amber-500/25 bg-amber-950/15 px-4 py-4",
        className,
      )}
      data-testid="archive-implications-card"
    >
      <h2 className={ARCHIVE_TYPO.sectionTitle}>{ARCHIVE_CASE_FILE_IMPLICATIONS_HEADLINE}</h2>
      <ul className="mt-3 space-y-2">
        {view.headlineLines.map((line) => (
          <li key={line} className={`${ARCHIVE_TYPO.body} text-zinc-200`}>
            {line}
          </li>
        ))}
      </ul>
    </section>
  );
}
