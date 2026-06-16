"use client";

import { useMemo } from "react";

import { buildArchiveBeliefObject } from "@/lib/archive/build-archive-belief-object";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveHealthSummaryProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

const CARD_LABELS = ["Belief", "Evidence", "Trust", "Change"] as const;

/** Archive home — single 4-card strip for belief health at a glance. */
export function ArchiveHealthSummary({
  entriesOverride,
  className = "",
}: ArchiveHealthSummaryProps) {
  const hydrated = useClientHydrated();

  const beliefObject = useMemo(() => {
    if (!hydrated) return null;
    return buildArchiveBeliefObject(entriesOverride ?? getMemoryEligibleEntries());
  }, [hydrated, entriesOverride]);

  if (!beliefObject) return null;

  const trustLine =
    beliefObject.trustReasons[0] ?? beliefObject.reputation.slice(0, 80);
  const changeLine =
    beliefObject.whatChanged[0] ?? "No movement lines yet — archive is stable.";

  const cards = [
    {
      label: CARD_LABELS[0],
      value: beliefObject.belief,
    },
    {
      label: CARD_LABELS[1],
      value:
        beliefObject.evidenceCount > 0
          ? `${beliefObject.evidenceCount} evidence items`
          : "Gathering evidence",
    },
    {
      label: CARD_LABELS[2],
      value: trustLine,
    },
    {
      label: CARD_LABELS[3],
      value: changeLine,
    },
  ] as const;

  return (
    <section
      className={cn("grid grid-cols-2 gap-2 sm:grid-cols-4", className)}
      data-testid="archive-health-summary"
      aria-label="Archive health"
    >
      {cards.map((card) => (
        <article
          key={card.label}
          className="rounded-xl border border-white/10 bg-black/30 px-3 py-3"
          data-archive-health={card.label.toLowerCase()}
        >
          <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
            {card.label}
          </p>
          <p className="mt-1.5 line-clamp-3 text-xs leading-relaxed text-zinc-300">
            {card.value}
          </p>
        </article>
      ))}
    </section>
  );
}
