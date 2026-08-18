"use client";

import { useEffect, useMemo, useRef } from "react";

import { EVOLVING_VIEW_CARD } from "@/lib/product/evolving-understanding-copy";
import { buildEvolvingViewSnapshot } from "@/lib/theories/evolving-view-snapshot";
import { trackEvolvingViewCardSeen } from "@/lib/metrics/evolving-understanding-events";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

interface EvolvingViewCardProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  surface: string;
  /** Hide until at least this many reflections (default 5). */
  minReflections?: number;
}

function formatUpdated(iso: string | null): string | null {
  if (!iso) return null;
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  } catch {
    return null;
  }
}

export function EvolvingViewCard({
  className = "",
  entriesOverride,
  surface,
  minReflections = 5,
}: EvolvingViewCardProps) {
  const hydrated = useClientHydrated();
  const seenRef = useRef(false);
  const entries = entriesOverride ?? (hydrated ? getMemoryEligibleEntries() : []);
  const reflectionCount = entries.filter((e) => e.reflectionPending !== true).length;

  const snapshot = useMemo(
    () => (hydrated ? buildEvolvingViewSnapshot(entries) : null),
    [hydrated, entries],
  );

  useEffect(() => {
    if (!hydrated || seenRef.current || reflectionCount < minReflections) return;
    seenRef.current = true;
    trackEvolvingViewCardSeen(surface);
  }, [hydrated, reflectionCount, minReflections, surface]);

  if (!hydrated || reflectionCount < minReflections || !snapshot) return null;
  if (snapshot.totalTheories === 0 && reflectionCount < minReflections) return null;

  const updatedLabel = formatUpdated(snapshot.lastUpdated);

  return (
    <div
      className={`rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4 text-left ${className}`}
      data-testid="evolving-view-card"
    >
      <p className="text-sm font-medium text-zinc-200">{EVOLVING_VIEW_CARD.headline}</p>
      <p className="mt-1 text-sm leading-relaxed text-zinc-500">{EVOLVING_VIEW_CARD.subline}</p>
      <dl className="mt-4 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
        <div>
          <dt className="text-xs text-zinc-600">{EVOLVING_VIEW_CARD.totalTheories}</dt>
          <dd className="mt-0.5 font-medium tabular-nums text-zinc-300">
            {snapshot.totalTheories}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-zinc-600">{EVOLVING_VIEW_CARD.underReview}</dt>
          <dd className="mt-0.5 font-medium tabular-nums text-zinc-300">
            {snapshot.underReviewCount}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-zinc-600">{EVOLVING_VIEW_CARD.strengthening}</dt>
          <dd className="mt-0.5 font-medium tabular-nums text-zinc-300">
            {snapshot.strengtheningCount}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-zinc-600">{EVOLVING_VIEW_CARD.weakeningResolved}</dt>
          <dd className="mt-0.5 font-medium tabular-nums text-zinc-300">
            {snapshot.weakeningOrResolvedCount}
          </dd>
        </div>
      </dl>
      {updatedLabel ? (
        <p className="mt-3 text-xs text-zinc-600">
          {EVOLVING_VIEW_CARD.lastUpdated}: {updatedLabel}
        </p>
      ) : null}
    </div>
  );
}
