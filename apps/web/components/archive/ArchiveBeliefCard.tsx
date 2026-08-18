"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";

import { BeliefChangeTimeline } from "@/components/archive/BeliefChangeTimeline";
import { ArchiveBeliefEvidenceSection } from "@/components/archive/ArchiveBeliefEvidenceSection";
import {
  ARCHIVE_BELIEF_EMPTY,
  ARCHIVE_BELIEF_HEADLINE,
  ARCHIVE_BELIEF_PREFIX,
  ARCHIVE_BELIEF_WHAT_CHANGED_TITLE,
} from "@/lib/archive/archive-belief-copy";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  trackArchiveBeliefExpanded,
  trackArchiveBeliefViewed,
  trackBeliefChangeViewed,
} from "@/lib/metrics/archive-belief-events";
import type { JournalEntry } from "@/types/journal";

interface ArchiveBeliefCardProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  surface?: string;
}

export function ArchiveBeliefCard({
  className = "",
  entriesOverride,
  surface = "discover",
}: ArchiveBeliefCardProps) {
  const hydrated = useClientHydrated();
  const viewedRef = useRef(false);
  const changeViewedRef = useRef(false);
  const expandedTrackedRef = useRef(false);
  const [evidenceExpanded, setEvidenceExpanded] = useState(false);

  const belief = useMemo(
    () => (hydrated ? buildArchiveBeliefView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  useEffect(() => {
    if (!belief || viewedRef.current) return;
    viewedRef.current = true;
    trackArchiveBeliefViewed({ theoryId: belief.theoryId, surface });
  }, [belief, surface]);

  useEffect(() => {
    if (!belief || changeViewedRef.current || belief.changeLines.length === 0) return;
    changeViewedRef.current = true;
    trackBeliefChangeViewed({ theoryId: belief.theoryId, surface });
  }, [belief, surface]);

  const toggleEvidence = () => {
    const next = !evidenceExpanded;
    setEvidenceExpanded(next);
    if (next && belief && !expandedTrackedRef.current) {
      expandedTrackedRef.current = true;
      trackArchiveBeliefExpanded({ theoryId: belief.theoryId, surface });
    }
  };

  if (!hydrated) return null;

  if (!belief) {
    return (
      <div
        className={`rounded-2xl border border-dashed border-white/10 bg-black/20 px-4 py-6 text-sm text-zinc-500 ${className}`}
        data-testid="archive-belief-card"
        data-belief-empty="true"
      >
        <p className="text-xs uppercase tracking-[0.16em] text-zinc-600">
          {ARCHIVE_BELIEF_HEADLINE}
        </p>
        <p className="mt-2 leading-relaxed">{ARCHIVE_BELIEF_EMPTY}</p>
      </div>
    );
  }

  return (
    <div
      className={`rounded-2xl border border-violet-500/25 bg-violet-950/20 px-4 py-4 text-left ${className}`}
      data-testid="archive-belief-card"
      data-belief-status={belief.status}
    >
      <p className="text-xs uppercase tracking-[0.16em] text-violet-300/90">
        {ARCHIVE_BELIEF_HEADLINE}
      </p>

      <p className="mt-3 text-sm text-zinc-500">{ARCHIVE_BELIEF_PREFIX}</p>
      <p className="mt-1 text-base font-medium leading-relaxed text-zinc-100">
        {belief.belief}
      </p>

      <dl className="mt-4 grid gap-3 sm:grid-cols-2">
        <div>
          <dt className="text-[10px] uppercase tracking-wider text-zinc-600">Confidence</dt>
          <dd className="mt-0.5 text-lg font-semibold tabular-nums text-violet-100">
            {belief.confidence}%
          </dd>
        </div>
        <div>
          <dt className="text-[10px] uppercase tracking-wider text-zinc-600">Status</dt>
          <dd className="mt-0.5 text-sm font-medium text-zinc-200">{belief.statusLabel}</dd>
          <dd className="mt-1 text-xs leading-relaxed text-zinc-500">
            {belief.statusExplanation}
          </dd>
        </div>
      </dl>

      {belief.changeLines.length > 0 ? (
        <div className="mt-4 border-t border-white/5 pt-4">
          <h3 className="text-sm font-medium text-zinc-300">{ARCHIVE_BELIEF_WHAT_CHANGED_TITLE}</h3>
          <ul className="mt-2 space-y-1.5 text-sm text-zinc-400">
            {belief.changeLines.map((line) => (
              <li key={line.id}>{line.text}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <BeliefChangeTimeline
        className="mt-4 border-t border-white/5 pt-4"
        entriesOverride={entriesOverride}
        theoryId={belief.theoryId}
      />

      <button
        type="button"
        onClick={toggleEvidence}
        className="mt-4 flex w-full items-center justify-between gap-2 text-left text-xs text-zinc-500 hover:text-zinc-300"
        aria-expanded={evidenceExpanded}
      >
        <span>Why the archive currently weighs this</span>
        <ChevronDown
          className={`h-4 w-4 shrink-0 transition ${evidenceExpanded ? "rotate-180" : ""}`}
          aria-hidden
        />
      </button>
      {evidenceExpanded ? (
        <div className="mt-3 border-t border-white/5 pt-4">
          <ArchiveBeliefEvidenceSection evidence={belief.evidence} />
        </div>
      ) : null}
    </div>
  );
}
