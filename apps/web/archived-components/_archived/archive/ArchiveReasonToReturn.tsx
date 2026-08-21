"use client";

import { useMemo } from "react";

import { buildArchiveReasonToReturn } from "@/lib/archive/archive-reason-to-return";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveReasonToReturnProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ArchiveReasonToReturn({
  entriesOverride,
  className,
}: ArchiveReasonToReturnProps) {
  const hydrated = useClientHydrated();
  const reason = useMemo(
    () => (hydrated ? buildArchiveReasonToReturn(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!reason) return null;

  return (
    <p
      className={cn(ARCHIVE_TYPO.body, "font-medium text-violet-200/90", className)}
      data-testid="archive-reason-to-return"
    >
      {reason.line}
    </p>
  );
}
