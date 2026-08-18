"use client";

import { useMemo } from "react";

import { ArchiveTransition } from "@/components/archive/ArchiveTransition";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import {
  ARCHIVE_REPUTATION_CONFIDENCE_FRAMING,
  ARCHIVE_REPUTATION_EARNED_LINE,
  ARCHIVE_REPUTATION_LEVEL_LABEL,
  ARCHIVE_REPUTATION_TITLE,
} from "@/lib/archive/archive-reputation-copy";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { ArchiveReputationLevel } from "@/types/archive-reputation";
import type { JournalEntry } from "@/types/journal";

const LEVEL_ACCENT: Record<ArchiveReputationLevel, string> = {
  low: "from-zinc-800/80 to-zinc-950/90 border-zinc-600/30",
  developing: "from-sky-950/30 to-zinc-950/90 border-sky-500/25",
  moderate: "from-violet-950/35 to-zinc-950/90 border-violet-500/30",
  high: "from-emerald-950/35 to-zinc-950/90 border-emerald-500/30",
  very_high: "from-amber-950/30 to-zinc-950/90 border-amber-400/35",
};

const METER_CELLS = 28;

type ArchiveReputationCardProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
  compact?: boolean;
  titleOverride?: string;
};

export function ArchiveReputationCard({
  entriesOverride,
  className = "",
  compact = false,
  titleOverride,
}: ArchiveReputationCardProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveReputationView(entries);
  }, [hydrated, entriesOverride]);

  if (!view) return null;

  const filledCells = Math.max(
    1,
    Math.round((view.meterFill / 100) * METER_CELLS),
  );

  return (
    <ArchiveTransition mode="card" testId="archive-reputation-card-wrap">
      <section
        className={cn(
          "rounded-2xl border bg-gradient-to-b px-4 py-4",
          LEVEL_ACCENT[view.level],
          className,
        )}
        data-testid="archive-reputation-card"
        data-archive-reputation-level={view.level}
      >
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className={ARCHIVE_TYPO.eyebrow}>{titleOverride ?? ARCHIVE_REPUTATION_TITLE}</p>
            <p className="mt-1 text-xs text-zinc-500">{ARCHIVE_REPUTATION_EARNED_LINE}</p>
          </div>
          <div className="text-right">
            <p className="text-[10px] uppercase tracking-wider text-zinc-500">Level</p>
            <p className="mt-0.5 font-mono text-sm font-semibold text-zinc-100">
              {ARCHIVE_REPUTATION_LEVEL_LABEL[view.level]}
            </p>
          </div>
        </div>

        <div
          className="mt-4 grid grid-cols-7 gap-1"
          aria-hidden
          data-testid="archive-reputation-meter"
        >
          {Array.from({ length: METER_CELLS }, (_, index) => (
            <span
              key={index}
              className={cn(
                "aspect-square rounded-sm",
                index < filledCells
                  ? "bg-violet-400/70"
                  : "bg-white/5",
              )}
            />
          ))}
        </div>

        <p className="mt-4 text-sm font-medium leading-relaxed text-zinc-200">
          {view.summary}
        </p>
        <p className={`${ARCHIVE_TYPO.caption} mt-2`}>
          {ARCHIVE_REPUTATION_CONFIDENCE_FRAMING}
        </p>

        <dl
          className={cn(
            "mt-4 grid gap-3 font-mono text-xs tabular-nums",
            compact ? "grid-cols-2" : "grid-cols-2 sm:grid-cols-3",
          )}
        >
          <Metric label="Supporting reflections" value={String(view.supportingReflections)} />
          <Metric label="Life areas" value={String(view.lifeAreas)} />
          <Metric label="Days tracked" value={String(view.daysTracked)} />
          <Metric label="Contradictions survived" value={String(view.contradictionsSurvived)} />
          <Metric label="Belief revisions" value={String(view.beliefChangesObserved)} />
          <Metric label="Accuracy signals" value={String(view.accuracySignals)} />
        </dl>
      </section>
    </ArchiveTransition>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-white/5 bg-black/20 px-2 py-2">
      <dt className="text-[10px] uppercase tracking-wide text-zinc-600">{label}</dt>
      <dd className="mt-0.5 text-sm text-zinc-200">{value}</dd>
    </div>
  );
}
