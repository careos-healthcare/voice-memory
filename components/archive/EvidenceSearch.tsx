"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

import { searchArchiveEvidence } from "@/lib/archive/evidence-search";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

interface EvidenceSearchProps {
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function EvidenceSearch({ className = "", entriesOverride }: EvidenceSearchProps) {
  const hydrated = useClientHydrated();
  const [query, setQuery] = useState("");

  const hits = useMemo(() => {
    if (!hydrated || query.trim().length < 2) return [];
    return searchArchiveEvidence(query, entriesOverride);
  }, [hydrated, query, entriesOverride]);

  if (!hydrated) return null;

  return (
    <section
      className={`rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4 ${className}`}
      data-testid="evidence-search"
      data-section="evidence-search"
    >
      <label className="block">
        <span className="text-xs font-medium text-zinc-400">Search your evidence</span>
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search your evidence…"
          className="mt-2 w-full rounded-xl border border-white/10 bg-zinc-950 px-3 py-2.5 text-sm text-white placeholder:text-zinc-600 focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
        />
      </label>

      {hits.length > 0 ? (
        <ul className="mt-4 space-y-3">
          {hits.map((hit) => (
            <li
              key={hit.id}
              className="rounded-lg border border-white/5 bg-black/20 px-3 py-3 text-sm"
            >
              <p className="leading-relaxed text-zinc-200">&ldquo;{hit.quote}&rdquo;</p>
              <p className="mt-1 text-xs text-zinc-500">
                {hit.beliefText}
                {hit.dateLabel ? ` · ${hit.dateLabel}` : ""}
              </p>
              {hit.entryId ? (
                <Link
                  href={`/memory/${hit.entryId}`}
                  className="mt-2 inline-block text-xs text-violet-300 hover:text-violet-200"
                >
                  Source moment →
                </Link>
              ) : null}
            </li>
          ))}
        </ul>
      ) : query.trim().length >= 2 ? (
        <p className="mt-3 text-xs text-zinc-600">No evidence matches that phrase yet.</p>
      ) : null}
    </section>
  );
}
