"use client";

import { useMemo } from "react";

import { buildArchivePulse } from "@/lib/archive/archive-pulse";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchivePulseProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchivePulse({ entriesOverride, className }: ArchivePulseProps) {
  const hydrated = useClientHydrated();
  const pulse = useMemo(
    () => (hydrated ? buildArchivePulse(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!pulse) return null;

  return (
    <p
      className={cn(ARCHIVE_TYPO.body, "text-violet-100/80", className)}
      data-testid="archive-pulse"
    >
      {pulse.line}
    </p>
  );
}
