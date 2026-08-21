"use client";

import { useMemo } from "react";

import { ArchiveTransition } from "@/archived-components/_archived/archive/ArchiveTransition";
import { buildBeliefSurvivalView, BELIEF_SURVIVAL_TITLE } from "@/lib/archive/belief-survival";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type BeliefSurvivalCardProps = {
  entriesOverride?: JournalEntry[];
  theoryId?: string;
  className?: string;
  variant?: "default" | "compact";
  titleOverride?: string;
};

export function BeliefSurvivalCard({
  entriesOverride,
  theoryId,
  className = "",
  variant = "default",
  titleOverride,
}: BeliefSurvivalCardProps) {
  const hydrated = useClientHydrated();

  const view = useMemo(() => {
    if (!hydrated) return null;
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildBeliefSurvivalView(entries, theoryId ? { theoryId } : undefined);
  }, [hydrated, entriesOverride, theoryId]);

  if (!view) return null;

  const compact = variant === "compact";

  return (
    <ArchiveTransition mode="card" testId="belief-survival-card-wrap">
      <section
        className={cn(
          "rounded-2xl border border-emerald-500/20 bg-gradient-to-b from-emerald-950/25 to-zinc-950/80 px-4 py-4",
          className,
        )}
        data-testid="belief-survival-card"
        data-section="belief-survival"
      >
        <p className={ARCHIVE_TYPO.eyebrow}>{titleOverride ?? BELIEF_SURVIVAL_TITLE}</p>

        {view.summaryLines.length > 0 ? (
          <div className="mt-3 space-y-1.5">
            {view.summaryLines.map((line) => (
              <p key={line} className="text-sm font-medium leading-relaxed text-zinc-200">
                {line}
              </p>
            ))}
          </div>
        ) : null}

        <dl
          className={cn(
            "mt-4 grid gap-3 text-xs",
            compact ? "grid-cols-2" : "sm:grid-cols-2",
          )}
        >
          <div>
            <dt className="text-zinc-600">Days alive</dt>
            <dd className="mt-0.5 font-mono tabular-nums text-zinc-200">{view.daysAlive}</dd>
          </div>
          <div>
            <dt className="text-zinc-600">Reflections supporting</dt>
            <dd className="mt-0.5 font-mono tabular-nums text-zinc-200">
              {view.reflectionsSupporting}
            </dd>
          </div>
          <div>
            <dt className="text-zinc-600">Contradictions survived</dt>
            <dd className="mt-0.5 font-mono tabular-nums text-zinc-200">
              {view.contradictionsSurvived}
            </dd>
          </div>
          <div>
            <dt className="text-zinc-600">First appeared</dt>
            <dd className="mt-0.5 text-zinc-300">{view.firstAppearedDate}</dd>
          </div>
        </dl>

        {view.confidenceMovementHistory.length > 0 ? (
          <div className="mt-4 border-t border-white/10 pt-4">
            <h3 className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
              Confidence movement history
            </h3>
            <ul className={`${ARCHIVE_TYPO.body} mt-2 max-h-36 space-y-2 overflow-y-auto`}>
              {view.confidenceMovementHistory.map((row) => (
                <li key={row.id}>
                  <span className="text-zinc-500">{row.label}</span>
                  <span className="text-zinc-600"> · </span>
                  <span className="text-zinc-400">{row.detail}</span>
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </section>
    </ArchiveTransition>
  );
}
