"use client";

import Link from "next/link";
import { useMemo } from "react";

import { ArchiveBeliefEvidenceSection } from "@/archived-components/_archived/archive/ArchiveBeliefEvidenceSection";
import { ArchiveLoadingState } from "@/archived-components/_archived/archive/ArchiveLoadingState";
import { ArchiveReputationCard } from "@/archived-components/_archived/archive/ArchiveReputationCard";
import { BeliefChangeTimeline } from "@/archived-components/_archived/archive/BeliefChangeTimeline";
import { WhyTheArchiveTrustsThis } from "@/archived-components/_archived/archive/WhyTheArchiveTrustsThis";
import { buildArchiveBeliefObject } from "@/lib/archive/build-archive-belief-object";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { toArchiveEmotionalCopy } from "@/lib/archive/archive-emotional-copy";
import { ARCHIVE_BELIEF_WHAT_CHANGED_TITLE } from "@/lib/archive/archive-belief-copy";
import {
  ARCHIVE_BELIEF_CENTRIC_MAX_VISIBLE,
  ARCHIVE_BELIEF_CENTRIC_PRIORITY,
  ARCHIVE_REDUCTION_MORE_LABEL,
  partitionArchiveSections,
} from "@/lib/archive/archive-reduction-rules";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { beliefJustificationFor } from "@/lib/product/archive-belief-justification";
import { justificationFor } from "@/lib/product/archive-feature-justification";
import type { JournalEntry } from "@/types/journal";

interface ArchiveCommandCenterProps {
  entriesOverride?: JournalEntry[];
  className?: string;
}

/** Belief-centric body — belief header renders separately; order: reputation → trust → change → timeline → evidence. */
export function ArchiveCommandCenter({
  entriesOverride,
  className = "",
}: ArchiveCommandCenterProps) {
  const hydrated = useClientHydrated();

  const beliefView = useMemo(
    () => (hydrated ? buildArchiveBeliefView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  const beliefObject = useMemo(
    () => (hydrated ? buildArchiveBeliefObject(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  const { visible, collapsed } = useMemo(() => {
    if (!beliefView || !beliefObject) {
      return { visible: [], collapsed: [] };
    }

    const sections = [
      {
        id: "reputation" as const,
        content: <ArchiveReputationCard entriesOverride={entriesOverride} />,
      },
      {
        id: "trust" as const,
        content: <WhyTheArchiveTrustsThis entriesOverride={entriesOverride} />,
      },
      {
        id: "movement" as const,
        content: (
          <div className="rounded-xl border border-white/10 bg-black/25 px-3 py-3">
            <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
              {ARCHIVE_BELIEF_WHAT_CHANGED_TITLE}
            </h3>
            {beliefObject.whatChanged.length > 0 ? (
              <ul className="mt-2 max-h-32 space-y-1 overflow-y-auto text-sm text-zinc-400">
                {beliefObject.whatChanged.slice(0, 5).map((line, index) => (
                  <li key={`${line}-${index}`} className="text-xs sm:text-sm">
                    {toArchiveEmotionalCopy(line)}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-2 text-xs text-zinc-600">No movement lines yet.</p>
            )}
            <Link
              href="/discover"
              className="mt-2 inline-block text-xs text-violet-300 hover:text-violet-200"
            >
              See archive changes →
            </Link>
          </div>
        ),
      },
      {
        id: "timeline" as const,
        content: (
          <div className="rounded-xl border border-violet-500/20 bg-violet-950/15 px-3 py-3">
            <h3 className="text-[10px] font-medium uppercase tracking-wider text-violet-300/80">
              Timeline
            </h3>
            <p className="mt-1 text-xs text-zinc-500">
              {beliefObject.timelinePoints > 0
                ? `${beliefObject.timelinePoints} belief shifts recorded`
                : "Timeline fills in as beliefs move"}
            </p>
            <div className="mt-2 max-h-44 overflow-y-auto">
              <BeliefChangeTimeline
                className="!border-0 !bg-transparent !p-0"
                entriesOverride={entriesOverride}
                theoryId={beliefView.theoryId}
              />
            </div>
          </div>
        ),
      },
      {
        id: "evidence" as const,
        content: (
          <div className="rounded-xl border border-white/10 bg-black/25 px-3 py-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
                Evidence
              </h3>
              <a
                href="#evidence-locker"
                className="text-xs text-violet-300 hover:text-violet-200"
              >
                Open evidence locker ↓
              </a>
            </div>
            <div className="mt-2 max-h-36 overflow-y-auto">
              <ArchiveBeliefEvidenceSection evidence={beliefView.evidence} />
            </div>
          </div>
        ),
      },
    ];

    return partitionArchiveSections(sections, {
      priority: ARCHIVE_BELIEF_CENTRIC_PRIORITY,
      maxVisible: ARCHIVE_BELIEF_CENTRIC_MAX_VISIBLE,
    });
  }, [beliefObject, beliefView, entriesOverride]);

  if (!hydrated) {
    return <ArchiveLoadingState variant="commandCenter" className={className} />;
  }

  if (!beliefView || !beliefObject) return null;

  return (
    <section
      className={className}
      data-testid="archive-command-center"
      data-archive-contribution={beliefJustificationFor("ArchiveCommandCenter").archiveContributionReason}
    >
      <p className="sr-only">{justificationFor("ArchiveCommandCenter")}</p>
      <div className="space-y-4">
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
    </section>
  );
}
