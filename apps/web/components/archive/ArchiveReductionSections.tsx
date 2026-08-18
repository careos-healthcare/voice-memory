"use client";

import type { ReactNode } from "react";

import {
  ARCHIVE_BELIEF_CENTRIC_MAX_VISIBLE,
  ARCHIVE_BELIEF_CENTRIC_PRIORITY,
  ARCHIVE_REDUCTION_MORE_LABEL,
  partitionArchiveSections,
  type ArchiveReductionSectionId,
} from "@/lib/archive/archive-reduction-rules";

type Section = {
  id: ArchiveReductionSectionId;
  content: ReactNode;
};

type ArchiveReductionSectionsProps = {
  sections: Section[];
  className?: string;
  beliefCentric?: boolean;
};

export function ArchiveReductionSections({
  sections,
  className = "",
  beliefCentric = false,
}: ArchiveReductionSectionsProps) {
  const { visible, collapsed } = partitionArchiveSections(sections, beliefCentric
    ? {
        priority: ARCHIVE_BELIEF_CENTRIC_PRIORITY,
        maxVisible: ARCHIVE_BELIEF_CENTRIC_MAX_VISIBLE,
      }
    : undefined);

  return (
    <div className={`space-y-4 ${className}`} data-testid="archive-reduction-sections">
      {visible.map((section) => (
        <div key={section.id} data-archive-reduction-visible={section.id}>
          {section.content}
        </div>
      ))}
      {collapsed.length > 0 ? (
        <details
          className="rounded-xl border border-white/10 bg-black/20"
          data-testid="archive-reduction-more"
        >
          <summary className="cursor-pointer px-4 py-3 text-sm text-zinc-400 marker:content-none [&::-webkit-details-marker]:hidden">
            {ARCHIVE_REDUCTION_MORE_LABEL}
          </summary>
          <div className="space-y-4 border-t border-white/5 px-4 py-4">
            {collapsed.map((section) => (
              <div key={section.id} data-archive-reduction-collapsed={section.id}>
                {section.content}
              </div>
            ))}
          </div>
        </details>
      ) : null}
    </div>
  );
}
