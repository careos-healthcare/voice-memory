"use client";

import { useEffect, useMemo, useRef } from "react";
import Link from "next/link";

import { buildArchiveProgressView } from "@/lib/archive/archive-maturity-engine";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  trackArchiveMaturityClicked,
  trackArchiveMaturitySeen,
} from "@/lib/metrics/archive-maturity-events";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveProgressBarProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
  surface: string;
  linkHref?: "/archive-belief" | "/discover" | null;
};

/** Dominant unified archive progression — replaces scattered progress meters. */
export function ArchiveProgressBar({
  entriesOverride,
  className = "",
  surface,
  linkHref = "/archive-belief",
}: ArchiveProgressBarProps) {
  const hydrated = useClientHydrated();
  const seenRef = useRef(false);

  const view = useMemo(
    () => (hydrated ? buildArchiveProgressView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  useEffect(() => {
    if (!view || seenRef.current) return;
    seenRef.current = true;
    trackArchiveMaturitySeen({ stage: view.stage, surface });
  }, [view, surface]);

  if (!view) return null;

  const inner = (
    <>
      <p className="text-sm font-medium leading-snug text-zinc-100">{view.headline}</p>
      <p className="mt-2 text-xs uppercase tracking-[0.16em] text-zinc-500">
        Current stage · {view.stageLabel}
      </p>
      <div
        className="mt-2 h-2 overflow-hidden rounded-full bg-zinc-800"
        role="progressbar"
        aria-valuenow={view.score}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label="Archive maturity"
      >
        <div
          className="h-full rounded-full bg-violet-500/85 transition-all"
          style={{ width: `${view.score}%` }}
        />
      </div>
      <p className="mt-2 font-mono text-xs tabular-nums text-zinc-300">{view.score}%</p>
      <p className="mt-2 text-xs leading-relaxed text-zinc-500">
        Next milestone ({view.nextMilestonePercent}%): {view.nextMilestoneLabel}
      </p>
    </>
  );

  const shellClass = cn(
    "block rounded-2xl border border-violet-500/30 bg-violet-950/20 px-4 py-4 text-left",
    linkHref && "hover:border-violet-500/45",
    className,
  );

  if (linkHref) {
    return (
      <Link
        href={linkHref}
        className={shellClass}
        data-testid="archive-progress-bar"
        onClick={() => trackArchiveMaturityClicked({ stage: view.stage, surface })}
      >
        {inner}
      </Link>
    );
  }

  return (
    <div className={shellClass} data-testid="archive-progress-bar">
      {inner}
    </div>
  );
}
