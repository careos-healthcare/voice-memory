"use client";

import Link from "next/link";

import { RevisitEntryLink } from "@/components/navigation/RevisitEntryLink";
import { formatTerritoryDateRange } from "@/lib/territories/emotional-territories";
import {
  trackTerritoryContinueClicked,
  trackTerritoryEntryRevisited,
} from "@/lib/territories/territory-observation";
import type { EmotionalTerritory } from "@/types/emotional-territory";

export function TerritoryList({ territories }: { territories: EmotionalTerritory[] }) {
  if (territories.length === 0) return null;

  return (
    <ul className="space-y-10">
      {territories.map((territory) => (
        <li key={territory.id}>
          <Link
            href={`/territories/${territory.slug}`}
            className="group block space-y-3 px-1 py-1 transition-colors"
          >
            <p className="text-base font-normal text-zinc-200 transition-colors group-hover:text-zinc-100">
              {territory.label}
            </p>
            <p className="text-xs text-zinc-500">
              {territory.mentionCount} moment{territory.mentionCount === 1 ? "" : "s"}
            </p>
            {territory.continuityLines[0] ? (
              <p className="text-sm leading-relaxed text-zinc-500/90">
                {territory.continuityLines[0]}
              </p>
            ) : null}
          </Link>
        </li>
      ))}
    </ul>
  );
}

export function TerritoryMentionsSection({
  territories,
}: {
  territories: EmotionalTerritory[];
}) {
  if (territories.length === 0) return null;

  return (
    <section className="space-y-6">
      <h2 className="text-xs font-normal tracking-wide text-zinc-600">
        This also belongs around…
      </h2>
      <ul className="space-y-4">
        {territories.map((territory) => (
          <li key={territory.id}>
            <Link
              href={`/territories/${territory.slug}`}
              className="group block space-y-2 px-1 py-2 transition-colors"
            >
              <p className="text-sm font-normal text-zinc-400 transition-colors group-hover:text-zinc-300">
                {territory.label}
              </p>
              <p className="text-xs text-zinc-600">
                {territory.mentionCount} moment{territory.mentionCount === 1 ? "" : "s"} ·{" "}
                {formatTerritoryDateRange(territory)}
              </p>
            </Link>
          </li>
        ))}
      </ul>
      <Link
        href="/territories"
        className="inline-block px-1 text-xs text-zinc-600 transition-colors hover:text-zinc-400"
      >
        All territories
      </Link>
    </section>
  );
}

export function TerritoryDetail({ territory }: { territory: EmotionalTerritory }) {
  const evolutionBlocks = [
    territory.evolution.whatChanged
      ? { title: "What changed", text: territory.evolution.whatChanged }
      : null,
    territory.evolution.whatCameBack
      ? { title: "What came back", text: territory.evolution.whatCameBack }
      : null,
    territory.evolution.whatGotQuieter
      ? { title: "What got quieter", text: territory.evolution.whatGotQuieter }
      : null,
  ].filter(Boolean) as Array<{ title: string; text: string }>;

  return (
    <div className="space-y-20">
      <header className="space-y-4">
        <h1 className="text-2xl font-normal tracking-tight text-zinc-100 sm:text-3xl">
          {territory.label}
        </h1>
        <p className="text-sm text-zinc-500">
          {territory.mentionCount} related moment
          {territory.mentionCount === 1 ? "" : "s"}
        </p>
        <div className="flex flex-wrap gap-x-6 gap-y-2 text-xs text-zinc-600">
          <span>Older: {territory.firstAppearanceLabel}</span>
          <span>Today: {territory.latestAppearanceLabel}</span>
        </div>
        {territory.continuityLines.length > 0 ? (
          <ul className="space-y-2 pt-2">
            {territory.continuityLines.map((line) => (
              <li key={line} className="text-sm leading-relaxed text-zinc-500/90">
                {line}
              </li>
            ))}
          </ul>
        ) : null}
      </header>

      {evolutionBlocks.length > 0 ? (
        <section className="space-y-8">
          {evolutionBlocks.map((block) => (
            <div key={block.title} className="space-y-2 px-1">
              <h2 className="text-xs font-normal tracking-wide text-zinc-600">{block.title}</h2>
              <p className="text-sm leading-[1.75] text-zinc-500/90">{block.text}</p>
            </div>
          ))}
        </section>
      ) : null}

      <section className="space-y-6">
        <h2 className="text-xs font-normal tracking-wide text-zinc-600">Related moments</h2>
        <ul className="space-y-6">
          {territory.relatedReflections.map((related) => (
            <li key={related.entryId}>
              <RevisitEntryLink
                entryId={related.entryId}
                source="memory_note"
                noteId={`territory-${territory.id}`}
                noteText={related.snippet}
                className="group block space-y-2 px-1 py-2 transition-colors"
                onNavigate={() =>
                  trackTerritoryEntryRevisited(territory.id, related.entryId)
                }
              >
                <p className="text-xs text-zinc-600">{related.dateLabel}</p>
                {related.snippet ? (
                  <p className="text-sm leading-[1.75] text-zinc-500/90 transition-colors group-hover:text-zinc-400">
                    {related.snippet}
                  </p>
                ) : (
                  <p className="text-sm text-zinc-600 transition-colors group-hover:text-zinc-400">
                    View moment
                  </p>
                )}
              </RevisitEntryLink>
            </li>
          ))}
        </ul>
      </section>

      <section className="space-y-4 border-t border-white/[0.06] pt-10">
        <h2 className="text-xs font-normal tracking-wide text-zinc-600">Continue from here</h2>
        <div className="flex flex-wrap gap-4 text-sm">
          <Link
            href={`/feelings-timeline?territory=${encodeURIComponent(territory.id)}`}
            className="text-violet-300 hover:text-violet-200"
            onClick={() => trackTerritoryContinueClicked(territory.id, "feelings")}
          >
            Feelings in this context →
          </Link>
          <Link
            href="/roundups"
            className="text-violet-300 hover:text-violet-200"
            onClick={() => trackTerritoryContinueClicked(territory.id, "roundups")}
          >
            Roundups →
          </Link>
          <Link
            href="/intentions"
            className="text-zinc-500 hover:text-zinc-300"
            onClick={() => trackTerritoryContinueClicked(territory.id, "intentions")}
          >
            Intentions →
          </Link>
        </div>
      </section>
    </div>
  );
}
