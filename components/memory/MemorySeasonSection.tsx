"use client";

import Link from "next/link";

import type { MemorySeason } from "@/types/memory-season";

export function MemorySeasonList({
  seasons,
}: {
  seasons: MemorySeason[];
}) {
  if (seasons.length === 0) return null;

  return (
    <ul className="space-y-16">
      {seasons.map((season) => (
        <li key={season.period.id}>
          <article className="space-y-5 px-1">
            <div className="space-y-3">
              <h2 className="text-base font-normal text-zinc-200">
                {season.period.label}
              </h2>
              <p className="text-sm leading-[1.75] text-zinc-500/90">{season.headline}</p>
              <p className="text-xs text-zinc-600">
                {season.period.entryCount} moment
                {season.period.entryCount === 1 ? "" : "s"}
              </p>
            </div>

            {season.observations.length > 1 ? (
              <ul className="space-y-3 border-l border-white/5 pl-4">
                {season.observations
                  .filter((observation) => observation.text !== season.headline)
                  .map((observation) => (
                    <li
                      key={observation.id}
                      className="text-sm leading-[1.75] text-zinc-600"
                    >
                      {observation.text}
                    </li>
                  ))}
              </ul>
            ) : null}

            <div className="flex flex-wrap gap-2 pt-1">
              {season.period.entryIds.slice(0, 4).map((entryId) => (
                <Link
                  key={entryId}
                  href={`/entry/${entryId}`}
                  className="text-xs text-zinc-600 transition-colors hover:text-zinc-400"
                >
                  View moment
                </Link>
              ))}
              {season.period.entryCount > 4 ? (
                <span className="text-xs text-zinc-700">
                  +{season.period.entryCount - 4} more
                </span>
              ) : null}
            </div>
          </article>
        </li>
      ))}
    </ul>
  );
}

export function MemorySeasonOverview({
  calendarSeasons,
  monthlyPeriods,
}: {
  calendarSeasons: MemorySeason[];
  monthlyPeriods: MemorySeason[];
}) {
  return (
    <div className="space-y-20">
      {calendarSeasons.length > 0 ? (
        <section>
          <MemorySeasonList seasons={calendarSeasons} />
        </section>
      ) : null}

      {monthlyPeriods.length > 0 ? (
        <section>
          <MemorySeasonList seasons={monthlyPeriods} />
        </section>
      ) : null}
    </div>
  );
}
