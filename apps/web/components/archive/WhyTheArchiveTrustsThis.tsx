"use client";

import { useMemo } from "react";

import { buildWhyArchiveTrustsThisLines } from "@/lib/archive/archive-reputation-trust";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export const WHY_ARCHIVE_TRUSTS_TITLE = "Why the archive trusts this";

type WhyTheArchiveTrustsThisProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function WhyTheArchiveTrustsThis({
  entriesOverride,
  className = "",
}: WhyTheArchiveTrustsThisProps) {
  const hydrated = useClientHydrated();

  const lines = useMemo(() => {
    if (!hydrated) return [];
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildWhyArchiveTrustsThisLines(entries);
  }, [hydrated, entriesOverride]);

  if (lines.length === 0) return null;

  return (
    <section
      className={cn("rounded-xl border border-white/10 bg-black/25 px-3 py-3", className)}
      data-testid="why-archive-trusts-this"
    >
      <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
        {WHY_ARCHIVE_TRUSTS_TITLE}
      </h3>
      <ul className={`${ARCHIVE_TYPO.body} mt-2 space-y-1.5`}>
        {lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
    </section>
  );
}
