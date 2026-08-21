"use client";

import { useEffect, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";

import { ArchiveTransition } from "@/archived-components/_archived/archive/ArchiveTransition";
import {
  persistArchiveMovement,
  trackArchiveUpdateExpanded,
  trackArchiveUpdateSeen,
} from "@/lib/metrics/archive-movement-events";
import type { ArchiveMovementUpdate } from "@/types/archive-movement";

interface ArchiveMovementCardProps {
  update: ArchiveMovementUpdate;
  className?: string;
  /** Persist to voicememory_archive_updates when shown after save. */
  persist?: boolean;
  entryId?: string;
  reflectionCount?: number;
  defaultExpanded?: boolean;
}

export function ArchiveMovementCard({
  update,
  className = "",
  persist = false,
  entryId,
  reflectionCount,
  defaultExpanded = false,
}: ArchiveMovementCardProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);
  const seenRef = useRef(false);

  useEffect(() => {
    if (seenRef.current) return;
    seenRef.current = true;
    if (persist) {
      persistArchiveMovement(update, { entryId, reflectionCount });
    }
    trackArchiveUpdateSeen(update);
  }, [update, persist, entryId, reflectionCount]);

  const toggleExpanded = () => {
    const next = !expanded;
    setExpanded(next);
    if (next) trackArchiveUpdateExpanded(update);
  };

  return (
    <ArchiveTransition mode="movement" motionKey={update.id} className={className}>
    <div
      className="rounded-2xl border border-violet-500/20 bg-violet-950/15 px-4 py-4 text-left"
      data-testid="archive-movement-card"
      data-movement-kind={update.kind}
    >
      <p className="text-xs uppercase tracking-[0.16em] text-violet-300/90">{update.eyebrow}</p>
      <p className="mt-2 text-sm font-medium text-zinc-100">{update.headline}</p>
      {update.detailLine ? (
        <p className="mt-1 text-sm tabular-nums text-violet-200/90">{update.detailLine}</p>
      ) : null}
      <button
        type="button"
        onClick={toggleExpanded}
        className="mt-3 flex w-full items-center justify-between gap-2 text-left text-xs text-zinc-500 hover:text-zinc-400"
        aria-expanded={expanded}
      >
        <span>Reason</span>
        <ChevronDown
          className={`h-4 w-4 shrink-0 transition ${expanded ? "rotate-180" : ""}`}
          aria-hidden
        />
      </button>
      {expanded ? (
        <p className="mt-2 text-sm leading-relaxed text-zinc-400">{update.reason}</p>
      ) : null}
    </div>
    </ArchiveTransition>
  );
}
