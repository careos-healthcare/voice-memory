"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight, Search } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  SEARCH_FIELD_LABELS,
  searchJournalEntries,
  type SearchField,
} from "@/lib/journal-search";
import { formatRelativeDate } from "@/lib/utils";

export default function SearchPage() {
  const [query, setQuery] = useState("");

  const results = useMemo(() => searchJournalEntries(query), [query]);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-16 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            Search your life
          </p>
          <h1 className="mt-2 text-3xl font-semibold text-white">Search</h1>
          <p className="mt-2 text-sm text-zinc-400">
            Find moments across transcript, mood, themes, concerns, and positive
            signals — all stored locally.
          </p>
        </motion.div>

        <div className="relative mt-8">
          <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-500" />
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Try “anxious”, “work”, or a theme…"
            className="w-full rounded-2xl border border-white/10 bg-white/[0.04] py-3.5 pl-11 pr-4 text-sm text-white placeholder:text-zinc-600 focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
            autoFocus
          />
        </div>

        <p className="mt-3 text-xs text-zinc-600">
          Searches transcript · mood · themes · hidden concern · positive signal
        </p>

        <div className="mt-8 space-y-3">
          {query.trim().length === 0 ? (
            <Card className="border-dashed">
              <CardContent className="px-6 py-10 text-center text-sm text-zinc-500">
                Type to search your journal entries on this device.
              </CardContent>
            </Card>
          ) : results.length === 0 ? (
            <Card>
              <CardContent className="px-6 py-10 text-center">
                <p className="text-sm font-medium text-white">No matches</p>
                <p className="mt-2 text-sm text-zinc-500">
                  Nothing in your local journal matched &ldquo;{query}&rdquo;.
                </p>
              </CardContent>
            </Card>
          ) : (
            results.map((result, index) => (
              <motion.div
                key={result.entry.id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.03 }}
              >
                <Link href={`/entry/${result.entry.id}`} className="group block">
                  <Card className="transition-colors hover:border-violet-400/30 hover:bg-white/[0.04]">
                    <CardContent className="p-5">
                      <div className="flex items-start justify-between gap-4">
                        <div className="min-w-0 flex-1">
                          <div className="flex flex-wrap items-center gap-2">
                            <Badge className="capitalize">
                              {result.entry.reflection.mood}
                            </Badge>
                            <span className="text-xs text-zinc-500">
                              {formatRelativeDate(result.entry.createdAt)}
                            </span>
                          </div>
                          <p className="mt-3 text-sm leading-relaxed text-zinc-300">
                            {result.snippet}
                          </p>
                          <div className="mt-3 flex flex-wrap gap-1.5">
                            {result.matchedFields.map((field: SearchField) => (
                              <span
                                key={field}
                                className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] uppercase tracking-wide text-zinc-500"
                              >
                                {SEARCH_FIELD_LABELS[field]}
                              </span>
                            ))}
                          </div>
                        </div>
                        <ArrowRight className="mt-1 h-4 w-4 shrink-0 text-zinc-600 transition-transform group-hover:translate-x-0.5 group-hover:text-violet-300" />
                      </div>
                    </CardContent>
                  </Card>
                </Link>
              </motion.div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
