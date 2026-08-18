"use client";

import { useMemo } from "react";

import { buildWhatIsMyArchiveView } from "@/lib/archive/what-is-my-archive";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type WhatIsMyArchiveProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
  compact?: boolean;
};

export function WhatIsMyArchive({
  entriesOverride,
  className = "",
  compact = false,
}: WhatIsMyArchiveProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildWhatIsMyArchiveView(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-white/10 bg-zinc-900/50 px-4 py-4",
        className,
      )}
      data-testid="what-is-my-archive"
    >
      <ul
        className={cn(
          "space-y-1.5 text-zinc-300",
          compact ? "text-xs leading-relaxed" : "text-sm leading-relaxed",
        )}
      >
        {view.bodyLines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>

      <div className="mt-4 border-t border-white/10 pt-3">
        <p className={ARCHIVE_TYPO.eyebrow}>Current stage</p>
        <p className={cn("mt-1 text-zinc-200", compact ? "text-xs" : "text-sm")}>
          <span className="text-zinc-500">{view.currentStage.reflectionRange}:</span>{" "}
          {view.currentStage.label}
        </p>
      </div>
    </section>
  );
}
