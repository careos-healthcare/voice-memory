"use client";

import { useEffect, useMemo, useRef } from "react";

import { ArchiveEmptyState } from "@/components/archive/ArchiveEmptyState";
import { ArchiveLoadingState } from "@/components/archive/ArchiveLoadingState";
import { ArchiveTransition } from "@/components/archive/ArchiveTransition";
import {
  BELIEF_TIMELINE_EMPTY,
  BELIEF_TIMELINE_LEAD,
  BELIEF_TIMELINE_TITLE,
} from "@/lib/archive/belief-timeline-copy";
import { buildBeliefChangeTimeline } from "@/lib/archive/belief-timeline";
import { toArchiveEmotionalCopy } from "@/lib/archive/archive-emotional-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { trackBeliefTimelineViewed } from "@/lib/metrics/archive-belief-events";
import type { JournalEntry } from "@/types/journal";

interface BeliefChangeTimelineProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  theoryId?: string;
  /** Larger layout for Evidence Archive home. */
  dominant?: boolean;
}

export function BeliefChangeTimeline({
  className = "",
  entriesOverride,
  theoryId,
  dominant = false,
}: BeliefChangeTimelineProps) {
  const hydrated = useClientHydrated();
  const seenRef = useRef(false);

  const timeline = useMemo(
    () =>
      hydrated ? buildBeliefChangeTimeline(entriesOverride, { theoryId }) : null,
    [hydrated, entriesOverride, theoryId],
  );

  useEffect(() => {
    if (!timeline || seenRef.current) return;
    seenRef.current = true;
    trackBeliefTimelineViewed({ theoryId: timeline.theoryId });
  }, [timeline]);

  if (!hydrated) {
    return <ArchiveLoadingState variant="timeline" className={className} ariaLabel="Timeline preparing" />;
  }

  if (!timeline || timeline.points.length === 0) {
    return (
      <ArchiveEmptyState
        className={className}
        title="No belief changes yet"
        body={BELIEF_TIMELINE_EMPTY}
        testId="belief-change-timeline-empty"
      />
    );
  }

  const titleClass = dominant ? "text-base font-semibold text-zinc-100" : "text-sm font-medium text-zinc-300";

  return (
    <section
      className={`space-y-3 ${className}`}
      data-testid="belief-change-timeline"
      data-point-count={timeline.points.length}
      data-dominant={dominant ? "true" : undefined}
    >
      <div>
        <h3 className={titleClass}>{BELIEF_TIMELINE_TITLE}</h3>
        <p className="mt-1 text-xs leading-relaxed text-zinc-600">{BELIEF_TIMELINE_LEAD}</p>
      </div>
      <ol
        className={`relative space-y-0 border-l pl-4 ${
          dominant ? "border-violet-400/40 pl-5" : "border-violet-500/25"
        }`}
      >
        {timeline.points.map((point, index) => (
          <li key={point.id} className="relative pb-6 last:pb-0">
            <ArchiveTransition mode="timeline" staggerIndex={index} motionKey={point.id}>
            <span
              className={`absolute top-1 rounded-full bg-violet-400/80 ${
                dominant ? "-left-[1.45rem] h-2.5 w-2.5" : "-left-[1.3rem] h-2 w-2"
              }`}
              aria-hidden
            />
            <p className={dominant ? "text-base font-medium text-zinc-100" : "text-sm font-medium text-zinc-200"}>
              {point.periodLabel}
            </p>
            <p
              className={`mt-0.5 font-semibold tabular-nums text-violet-100 ${
                dominant ? "text-2xl" : "text-lg"
              }`}
            >
              <ArchiveTransition mode="confidence" motionKey={point.confidence}>
                {point.confidence}%
              </ArchiveTransition>
            </p>
            <p className="text-xs font-medium text-zinc-400">{point.statusLabel}</p>
            <p className="mt-1 text-xs leading-relaxed text-zinc-500">
              {toArchiveEmotionalCopy(point.whatChanged || point.note)}
            </p>
            <dl className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-[11px] text-zinc-600">
              <div>
                <dt className="inline">Evidence quotes: </dt>
                <dd className="inline tabular-nums text-zinc-500">{point.evidenceQuoteCount}</dd>
              </div>
              {point.lifeAreas.length > 0 ? (
                <div>
                  <dt className="inline">Life areas: </dt>
                  <dd className="inline text-zinc-500">{point.lifeAreas.join(", ")}</dd>
                </div>
              ) : null}
              {point.hasContradiction ? (
                <dd className="text-amber-500/80">Contradiction noted</dd>
              ) : null}
              {point.hasCostEvidence ? (
                <dd className="text-rose-500/80">Cost evidence</dd>
              ) : null}
            </dl>
            {index < timeline.points.length - 1 ? (
              <div className="mt-3 border-t border-white/5" aria-hidden />
            ) : null}
            </ArchiveTransition>
          </li>
        ))}
      </ol>
    </section>
  );
}
