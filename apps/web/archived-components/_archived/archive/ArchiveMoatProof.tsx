"use client";

import { useMemo } from "react";

import { buildArchiveMoatProofView } from "@/lib/archive/archive-moat-proof";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveMoatProofProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveMoatProof({ entriesOverride, className = "" }: ArchiveMoatProofProps) {
  const hydrated = useClientHydrated();
  const view = useMemo(
    () => (hydrated ? buildArchiveMoatProofView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!view) return null;

  return (
    <section
      className={cn("rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4", className)}
      data-testid="archive-moat-proof"
    >
      <p className={`${ARCHIVE_TYPO.body} font-medium text-zinc-100`}>{view.summaryLine}</p>
      <dl className="mt-4 space-y-3">
        {view.items.map((item) => (
          <div key={item.id}>
            <dt className="text-xs font-medium uppercase tracking-wide text-zinc-500">
              {item.question}
            </dt>
            <dd className={`${ARCHIVE_TYPO.caption} mt-1 text-zinc-300`}>{item.answer}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
