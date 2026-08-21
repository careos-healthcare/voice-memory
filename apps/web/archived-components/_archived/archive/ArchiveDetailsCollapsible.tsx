"use client";

import type { ReactNode, SyntheticEvent } from "react";

import { AdvancedArchiveDetail } from "@/archived-components/_archived/archive/AdvancedArchiveDetail";
import {
  ARCHIVE_ADVANCED_DETAIL_DESCRIPTION,
  ARCHIVE_ADVANCED_DETAIL_EYEBROW,
  ARCHIVE_ADVANCED_DETAIL_LEAD,
  ARCHIVE_DETAIL_LABEL,
} from "@/lib/archive/archive-disclosure-copy";
import { markArchiveDetailOpened } from "@/lib/archive/archive-disclosure-level";
import type { JournalEntry } from "@/types/journal";

interface ArchiveDetailsCollapsibleProps {
  entriesOverride?: JournalEntry[];
  className?: string;
  defaultOpen?: boolean;
  /** @deprecated children ignored — advanced detail renders on open */
  children?: ReactNode;
}

/** Archive detail gate — L3 advanced inspection on expand. */
export function ArchiveDetailsCollapsible({
  entriesOverride,
  className = "",
  defaultOpen = false,
}: ArchiveDetailsCollapsibleProps) {
  const handleToggle = (event: SyntheticEvent<HTMLDetailsElement>) => {
    if (event.currentTarget.open) {
      markArchiveDetailOpened();
    }
  };

  return (
    <details
      className={`group rounded-2xl border border-white/10 bg-zinc-900/30 ${className}`}
      data-testid="archive-details-collapsible"
      open={defaultOpen}
      onToggle={handleToggle}
    >
      <summary className="cursor-pointer list-none px-4 py-3 text-sm font-medium text-zinc-400 marker:content-none [&::-webkit-details-marker]:hidden">
        <span className="text-violet-300/90 group-open:text-violet-200">
          {ARCHIVE_DETAIL_LABEL}
        </span>
        <span className="ml-2 text-xs text-zinc-600">({ARCHIVE_ADVANCED_DETAIL_LEAD})</span>
      </summary>
      <div className="space-y-4 border-t border-white/5 px-4 py-4">
        <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
          {ARCHIVE_ADVANCED_DETAIL_EYEBROW}
        </p>
        <p className="text-sm leading-relaxed text-zinc-500">
          {ARCHIVE_ADVANCED_DETAIL_DESCRIPTION}
        </p>
        <AdvancedArchiveDetail entriesOverride={entriesOverride} />
      </div>
    </details>
  );
}
