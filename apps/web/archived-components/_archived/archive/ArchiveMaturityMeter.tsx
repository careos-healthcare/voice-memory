"use client";

import { ArchiveProgressBar } from "@/archived-components/_archived/archive/ArchiveProgressBar";
import type { JournalEntry } from "@/types/journal";

interface ArchiveMaturityMeterProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  surface: string;
  /** @deprecated use linkHref */
  linkToDiscover?: boolean;
  linkHref?: "/archive-belief" | "/discover" | null;
}

/** @deprecated Use ArchiveProgressBar — thin wrapper for legacy imports. */
export function ArchiveMaturityMeter({
  className = "",
  entriesOverride,
  surface,
  linkToDiscover,
  linkHref,
}: ArchiveMaturityMeterProps) {
  const href =
    linkHref ?? (linkToDiscover === false ? null : linkToDiscover ? "/discover" : "/archive-belief");

  return (
    <ArchiveProgressBar
      className={className}
      entriesOverride={entriesOverride}
      surface={surface}
      linkHref={href}
    />
  );
}
