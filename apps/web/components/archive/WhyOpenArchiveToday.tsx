"use client";

import { useMemo } from "react";

import { buildWhyOpenArchiveToday } from "@/lib/archive/why-open-archive-today";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type WhyOpenArchiveTodayProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function WhyOpenArchiveToday({ entriesOverride, className = "" }: WhyOpenArchiveTodayProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildWhyOpenArchiveToday(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <p
      className={cn(
        "rounded-xl border border-violet-500/20 bg-violet-950/25 px-3 py-2.5 text-sm font-medium text-violet-100/95",
        className,
      )}
      data-testid="why-open-archive-today"
    >
      {view.line}
    </p>
  );
}
