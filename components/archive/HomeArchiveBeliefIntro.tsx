"use client";

import Link from "next/link";

import {
  HOME_ARCHIVE_BELIEF_BULLETS,
  HOME_ARCHIVE_BELIEF_LEAD,
} from "@/lib/archive/archive-belief-copy";
import { ARCHIVE_WAYFINDING_TO_ARCHIVE } from "@/lib/product/archive-product-copy";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

interface HomeArchiveBeliefIntroProps {
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function HomeArchiveBeliefIntro({
  className = "",
  entriesOverride,
}: HomeArchiveBeliefIntroProps) {
  const hydrated = useClientHydrated();
  const belief = hydrated ? buildArchiveBeliefView(entriesOverride) : null;

  return (
    <div
      className={`rounded-2xl border border-zinc-700/40 bg-zinc-900/30 px-4 py-4 text-left ${className}`}
      data-testid="home-archive-belief-intro"
    >
      <p className="text-sm leading-relaxed text-zinc-200">{HOME_ARCHIVE_BELIEF_LEAD}</p>
      <p className="mt-3 text-sm text-zinc-500">Every moment can:</p>
      <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-zinc-400">
        {HOME_ARCHIVE_BELIEF_BULLETS.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
      {belief ? (
        <>
          <p className="mt-3 text-xs leading-relaxed text-violet-200/80">
            Current belief: {belief.belief.slice(0, 120)}
            {belief.belief.length > 120 ? "…" : ""}
          </p>
          <Link
            href="/archive-belief"
            className="mt-3 inline-block text-xs font-medium text-violet-300 hover:text-violet-200"
          >
            {ARCHIVE_WAYFINDING_TO_ARCHIVE} →
          </Link>
        </>
      ) : null}
    </div>
  );
}
