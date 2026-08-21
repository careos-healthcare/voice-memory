"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { AnimatedReveal } from "@/archived-components/_archived/motion/AnimatedReveal";
import { ArrowRight, Filter, Search } from "lucide-react";

import { EvidenceSearch } from "@/archived-components/_archived/archive/EvidenceSearch";
import { UpgradeCta } from "@/archived-components/_archived/billing/UpgradeCta";
import { ArchiveIdentityBar } from "@/archived-components/_archived/archive/ArchiveIdentityBar";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { EntryListRowMeta } from "@/archived-components/_archived/memory/EntryListRowMeta";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { RETENTION_EVENTS, trackRetentionEvent } from "@/lib/local-analytics";
import { APP_SUBTITLE } from "@/lib/product-copy";
import {
  EMPTY_LIFE_SEARCH_FILTERS,
  EXAMPLE_LIFE_QUERIES,
  getLifeSearchFilterOptions,
  LIFE_SEARCH_FIELD_LABELS,
  semanticLifeSearch,
  type ConfidenceLabel,
  type LifeSearchFilters,
} from "@/lib/semantic-life-search";

const MATCH_STYLES: Record<
  ConfidenceLabel,
  { label: string; className: string }
> = {
  high: {
    label: "Strong match",
    className: "border-emerald-500/30 bg-emerald-500/10 text-emerald-300",
  },
  medium: {
    label: "Good match",
    className: "border-violet-400/30 bg-violet-500/10 text-violet-200",
  },
  low: {
    label: "Possible match",
    className: "border-white/10 bg-white/5 text-zinc-400",
  },
};

function FilterSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <label className="flex min-w-0 flex-1 flex-col gap-1.5">
      <span className="text-[10px] font-medium uppercase tracking-wider text-muted">
        {label}
      </span>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
      >
        {options.map((opt) => (
          <option key={opt.value || "all"} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </label>
  );
}

export default function SearchPage() {
  const [query, setQuery] = useState("");
  const [filters, setFilters] = useState<LifeSearchFilters>(EMPTY_LIFE_SEARCH_FILTERS);
  const [showFilters, setShowFilters] = useState(false);
  const [filterOptions, setFilterOptions] = useState<{
    moods: string[];
    themes: string[];
  }>({ moods: [], themes: [] });
  const lastTrackedQuery = useRef("");

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setFilterOptions(getLifeSearchFilterOptions());
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const results = useMemo(
    () => semanticLifeSearch(query, filters),
    [query, filters],
  );

  const hasInput =
    query.trim().length > 0 ||
    filters.mood ||
    filters.theme ||
    filters.dateFrom ||
    filters.dateTo ||
    filters.intensityMin !== null ||
    filters.intensityMax !== null;

  useEffect(() => {
    if (!hasInput) return;
    const signature = JSON.stringify({ query: query.trim(), filters });
    if (signature === lastTrackedQuery.current) return;
    lastTrackedQuery.current = signature;
    trackRetentionEvent(RETENTION_EVENTS.searchPerformed, {
      queryLength: String(query.trim().length),
      resultCount: String(results.length),
    });
  }, [hasInput, query, filters, results.length]);

  const clearFilters = () => setFilters(EMPTY_LIFE_SEARCH_FILTERS);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
        <ArchiveIdentityBar className="mb-4" />
        <AnimatedReveal className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-200">
            {APP_SUBTITLE}
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Search your memory
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Search your private memory in plain language — thoughts, moods, themes,
            concerns, and people. All on this device.
          </p>
        </AnimatedReveal>

        <EvidenceSearch className="mt-6" />

        <div className="mt-6">
          <UpgradeCta
            source="search"
            feature="semantic_search"
            headline="Search your full memory in plain language"
            description="Semantic memory search on Free covers your last 7 entries. Pro searches moods, themes, concerns, and people across full history."
            compact
          />
        </div>

        <div className="relative mt-6">
          <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" aria-hidden />
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            aria-label="Search your memory"
            placeholder='Try "when did I feel anxious?"'
            className="w-full rounded-2xl border border-white/10 bg-white/[0.04] py-3.5 pl-11 pr-4 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
            autoFocus
          />
        </div>

        <div className="mt-3 flex flex-wrap gap-2">
          {EXAMPLE_LIFE_QUERIES.map((example) => (
            <button
              key={example}
              type="button"
              onClick={() => setQuery(example)}
              className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5 text-left text-xs text-zinc-300 transition-colors hover:border-violet-400/30 hover:text-violet-100"
            >
              {example}
            </button>
          ))}
        </div>

        <div className="mt-4">
          <Button
            type="button"
            variant="secondary"
            size="sm"
            className="w-full sm:w-auto"
            onClick={() => setShowFilters((v) => !v)}
          >
            <Filter className="h-4 w-4" />
            {showFilters ? "Hide filters" : "Filters"}
          </Button>
        </div>

        {showFilters ? (
          <Card className="mt-3 border-white/10">
            <CardContent className="space-y-4 p-4">
              <div className="flex flex-col gap-3 sm:flex-row">
                <FilterSelect
                  label="Mood"
                  value={filters.mood}
                  onChange={(mood) => setFilters((f) => ({ ...f, mood }))}
                  options={[
                    { value: "", label: "Any mood" },
                    ...filterOptions.moods.map((m) => ({
                      value: m,
                      label: m,
                    })),
                  ]}
                />
                <FilterSelect
                  label="Theme"
                  value={filters.theme}
                  onChange={(theme) => setFilters((f) => ({ ...f, theme }))}
                  options={[
                    { value: "", label: "Any theme" },
                    ...filterOptions.themes.map((t) => ({
                      value: t,
                      label: t,
                    })),
                  ]}
                />
              </div>

              <div className="flex flex-col gap-3 sm:flex-row">
                <label className="flex min-w-0 flex-1 flex-col gap-1.5">
                  <span className="text-[10px] font-medium uppercase tracking-wider text-muted">
                    From
                  </span>
                  <input
                    type="date"
                    value={filters.dateFrom}
                    onChange={(e) =>
                      setFilters((f) => ({ ...f, dateFrom: e.target.value }))
                    }
                    className="w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
                  />
                </label>
                <label className="flex min-w-0 flex-1 flex-col gap-1.5">
                  <span className="text-[10px] font-medium uppercase tracking-wider text-muted">
                    To
                  </span>
                  <input
                    type="date"
                    value={filters.dateTo}
                    onChange={(e) =>
                      setFilters((f) => ({ ...f, dateTo: e.target.value }))
                    }
                    className="w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
                  />
                </label>
              </div>

              <div className="flex flex-col gap-3 sm:flex-row">
                <label className="flex min-w-0 flex-1 flex-col gap-1.5">
                  <span className="text-[10px] font-medium uppercase tracking-wider text-muted">
                    Min intensity
                  </span>
                  <select
                    value={filters.intensityMin ?? ""}
                    onChange={(e) =>
                      setFilters((f) => ({
                        ...f,
                        intensityMin: e.target.value
                          ? Number(e.target.value)
                          : null,
                      }))
                    }
                    className="w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
                  >
                    <option value="">Any</option>
                    {Array.from({ length: 10 }, (_, i) => i + 1).map((n) => (
                      <option key={n} value={n}>
                        {n}/10
                      </option>
                    ))}
                  </select>
                </label>
                <label className="flex min-w-0 flex-1 flex-col gap-1.5">
                  <span className="text-[10px] font-medium uppercase tracking-wider text-muted">
                    Max intensity
                  </span>
                  <select
                    value={filters.intensityMax ?? ""}
                    onChange={(e) =>
                      setFilters((f) => ({
                        ...f,
                        intensityMax: e.target.value
                          ? Number(e.target.value)
                          : null,
                      }))
                    }
                    className="w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
                  >
                    <option value="">Any</option>
                    {Array.from({ length: 10 }, (_, i) => i + 1).map((n) => (
                      <option key={n} value={n}>
                        {n}/10
                      </option>
                    ))}
                  </select>
                </label>
              </div>

              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={clearFilters}
              >
                Clear filters
              </Button>
            </CardContent>
          </Card>
        ) : null}

        <p className="mt-3 flex items-center gap-1.5 text-xs text-muted">
          Search across transcript · mood · themes · concerns · signals · entities
        </p>

        <div className="mt-6 space-y-3">
          {!hasInput ? (
            <Card className="border-dashed">
              <CardContent className="px-6 py-10 text-center text-sm text-muted">
                Ask a question or apply filters to search across your voice
                reflections on this device.
              </CardContent>
            </Card>
          ) : results.length === 0 ? (
            <Card>
              <CardContent className="px-6 py-10 text-center">
                <p className="text-sm font-medium text-white">No matches</p>
                <p className="mt-2 text-sm text-muted">
                  Try a shorter phrase, an example query, or loosen your filters.
                </p>
              </CardContent>
            </Card>
          ) : (
            <>
              <p className="text-xs text-muted">
                {results.length} result{results.length === 1 ? "" : "s"}
              </p>
              {results.map((result, index) => {
                const matchStyle = MATCH_STYLES[result.matchLabel];
                const primary = result.matches[0];

                return (
                  <motion.div
                    key={result.entry.id}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.03 }}
                  >
                    <Link
                      href={`/entry/${result.entry.id}`}
                      className="group block"
                    >
                      <Card className="transition-colors hover:border-violet-400/30 hover:bg-white/[0.04]">
                        <CardContent className="p-4 sm:p-5">
                          <div className="flex items-start justify-between gap-3">
                            <div className="min-w-0 flex-1">
                              <div className="flex flex-wrap items-center gap-2">
                                <EntryListRowMeta createdAt={result.entry.createdAt} />
                                <span
                                  className={`rounded-full border px-2 py-0.5 text-[10px] font-medium ${matchStyle.className}`}
                                >
                                  {matchStyle.label}
                                </span>
                              </div>

                              {primary ? (
                                <div className="mt-3 rounded-xl bg-white/[0.03] px-3 py-2.5">
                                  <p className="text-[10px] uppercase tracking-wider text-violet-300/90">
                                    Matched &ldquo;{primary.matchedPhrase}&rdquo; in{" "}
                                    {LIFE_SEARCH_FIELD_LABELS[primary.field]}
                                  </p>
                                  <p className="mt-1.5 text-sm leading-relaxed text-zinc-300">
                                    {primary.snippet}
                                  </p>
                                </div>
                              ) : null}

                              {result.matches.length > 1 ? (
                                <ul className="mt-3 space-y-1.5">
                                  {result.matches.slice(1).map((match) => (
                                    <li
                                      key={`${match.field}-${match.matchedPhrase}`}
                                      className="text-xs text-muted"
                                    >
                                      <span className="text-zinc-400">
                                        {LIFE_SEARCH_FIELD_LABELS[match.field]}:
                                      </span>{" "}
                                      &ldquo;{match.matchedPhrase}&rdquo;
                                    </li>
                                  ))}
                                </ul>
                              ) : null}
                            </div>
                            <ArrowRight className="mt-1 h-4 w-4 shrink-0 text-muted transition-transform group-hover:translate-x-0.5 group-hover:text-violet-200" aria-hidden />
                          </div>
                        </CardContent>
                      </Card>
                    </Link>
                  </motion.div>
                );
              })}
            </>
          )}
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
