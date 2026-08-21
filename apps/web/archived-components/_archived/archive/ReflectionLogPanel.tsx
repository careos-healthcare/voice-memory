"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import { JournalArchiveRow } from "@/archived-components/_archived/journal/JournalArchiveRow";
import { AnticipatoryEmptyState } from "@/archived-components/_archived/memory/AnticipatoryEmptyState";
import { justificationFor } from "@/lib/product/archive-feature-justification";
import { isPrimarySurfacedReflection } from "@/lib/reflection/reflection-quality-gate";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

type ReflectionLogPanelProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

export function ReflectionLogPanel({
  entriesOverride,
  className = "",
}: ReflectionLogPanelProps) {
  const [query, setQuery] = useState("");

  const entries = useMemo(() => {
    const list = (entriesOverride ?? getMemoryEligibleEntries()).filter(
      isPrimarySurfacedReflection,
    );
    const q = query.trim().toLowerCase();
    if (!q) return list;
    return list.filter((e) => {
      const haystack = [
        e.transcript,
        e.reflection.concreteObservation,
        e.reflection.exactLanguagePattern,
        e.reflection.repeatedSignal,
        ...(e.reflection.recurringThemes ?? []),
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [entriesOverride, query]);

  if (entries.length === 0 && !query.trim()) {
    return (
      <AnticipatoryEmptyState
        entryCount={entriesOverride?.length ?? 0}
        className={className}
      />
    );
  }

  return (
    <div className={className} data-testid="reflection-log-panel">
      <p className="sr-only">{justificationFor("ReflectionLog")}</p>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <label className="flex-1">
          <span className="sr-only">Search reflections</span>
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search reflections…"
            className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200 placeholder:text-zinc-600"
          />
        </label>
        <Link
          href="/search"
          className="shrink-0 text-sm text-violet-300 hover:text-violet-200"
        >
          Advanced search →
        </Link>
      </div>

      {entries.length === 0 ? (
        <p className="mt-4 text-sm text-zinc-500">No reflections match that search.</p>
      ) : (
        <ul className="mt-4 space-y-2">
          {entries.map((entry) => (
            <li key={entry.id}>
              <JournalArchiveRow entry={entry} />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
