"use client";

import { ARCHIVE_V3_HEALTH } from "@/lib/archive/archive-reduction-v3-copy";
import { cn } from "@/lib/utils";
import type { ArchiveHealthLabel } from "@/types/archive-state-object";

type ArchiveHealthLineProps = {
  health: ArchiveHealthLabel;
  className?: string;
};

const HEALTH_CLASS: Record<ArchiveHealthLabel, string> = {
  Strong: "text-emerald-300/90",
  Developing: "text-violet-300/90",
  Uncertain: "text-amber-300/90",
};

/** One-line archive health — replaces reputation/ownership/maturity/accuracy on main surface. */
export function ArchiveHealthLine({ health, className = "" }: ArchiveHealthLineProps) {
  return (
    <p
      className={cn("text-sm text-zinc-500", className)}
      data-testid="archive-health-line"
    >
      <span className="text-[10px] font-medium uppercase tracking-wider text-zinc-600">
        {ARCHIVE_V3_HEALTH}
      </span>
      <span className="mx-2 text-zinc-700">·</span>
      <span className={cn("font-medium", HEALTH_CLASS[health])}>{health}</span>
    </p>
  );
}
