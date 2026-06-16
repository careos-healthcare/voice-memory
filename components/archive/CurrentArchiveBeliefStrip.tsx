"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef } from "react";

import {
  ARCHIVE_BELIEF_PREFIX,
  MEMORY_CURRENT_BELIEF_TITLE,
} from "@/lib/archive/archive-belief-copy";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { trackArchiveBeliefViewed } from "@/lib/metrics/archive-belief-events";
import type { JournalEntry } from "@/types/journal";

interface CurrentArchiveBeliefStripProps {
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function CurrentArchiveBeliefStrip({
  className = "",
  entriesOverride,
}: CurrentArchiveBeliefStripProps) {
  const hydrated = useClientHydrated();
  const viewedRef = useRef(false);

  const belief = useMemo(
    () => (hydrated ? buildArchiveBeliefView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  useEffect(() => {
    if (!belief || viewedRef.current) return;
    viewedRef.current = true;
    trackArchiveBeliefViewed({ theoryId: belief.theoryId, surface: "memory" });
  }, [belief]);

  if (!belief) return null;

  return (
    <section
      className={`rounded-2xl border border-violet-500/20 bg-violet-950/15 px-4 py-4 ${className}`}
      data-testid="current-archive-belief"
    >
      <div className="flex items-start justify-between gap-3">
        <p className="text-xs uppercase tracking-[0.16em] text-violet-300/80">
          {MEMORY_CURRENT_BELIEF_TITLE}
        </p>
        <Link
          href="/archive-belief"
          className="shrink-0 text-xs text-violet-300/90 hover:text-violet-200"
        >
          View archive
        </Link>
      </div>
      <p className="mt-2 text-[11px] text-zinc-600">{ARCHIVE_BELIEF_PREFIX}</p>
      <p className="mt-1 text-sm font-medium leading-relaxed text-zinc-100 line-clamp-3">
        {belief.belief}
      </p>
      <p className="mt-2 text-xs text-zinc-500">
        {belief.statusLabel} · {belief.confidence}% confidence
      </p>
    </section>
  );
}
