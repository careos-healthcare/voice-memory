"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { ArrowRight, BookOpen, Clock3 } from "lucide-react";

import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { getEntries } from "@/lib/storage";
import { getEntryPreviewLine } from "@/lib/reflection";
import { APP_HONESTY, APP_SUBTITLE } from "@/lib/product-copy";
import { formatEntryDate, formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export default function JournalPage() {
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setEntries(getEntries());
    setLoading(false);
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-16 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4"
        >
          <div className="flex items-end justify-between gap-4">
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
                {APP_SUBTITLE}
              </p>
              <h1 className="mt-2 text-3xl font-semibold text-white">Your reflections</h1>
              <p className="mt-2 text-sm text-zinc-400">
                Voice reflections on this device — {APP_HONESTY.toLowerCase()}
              </p>
            </div>
            <Button asChild variant="secondary" size="sm">
              <Link href="/">New entry</Link>
            </Button>
          </div>
        </motion.div>

        <div className="mt-8">
          <HabitLoopCard compact />
        </div>

        <div className="relative mt-10">
          {loading ? (
            <div className="space-y-4">
              {[1, 2, 3].map((item) => (
                <Skeleton key={item} className="h-28 w-full" />
              ))}
            </div>
          ) : entries.length === 0 ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <Card className="border-dashed">
                <CardContent className="flex flex-col items-center gap-4 px-6 py-14 text-center">
                  <div className="flex h-14 w-14 items-center justify-center rounded-full bg-violet-500/10">
                    <BookOpen className="h-6 w-6 text-violet-300" />
                  </div>
                  <div>
                    <p className="text-lg font-medium text-white">
                      No reflections yet
                    </p>
                    <p className="mt-2 max-w-sm text-sm text-zinc-400">
                      Talk naturally for a minute. VoiceMemory notices recurring
                      patterns over time — starting with one voice reflection.
                    </p>
                  </div>
                  <Button asChild>
                    <Link href="/">Start a reflection</Link>
                  </Button>
                </CardContent>
              </Card>
            </>
          ) : (
            <div className="relative space-y-4 before:absolute before:bottom-0 before:left-4 before:top-0 before:w-px before:bg-white/10 sm:before:left-5">
              {entries.map((entry, index) => (
                <motion.div
                  key={entry.id}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.05 }}
                >
                  <Link href={`/entry/${entry.id}`} className="group block">
                    <Card className="relative ml-8 transition-colors hover:border-violet-400/30 hover:bg-white/[0.05] sm:ml-10">
                      <CardContent className="p-5">
                        <div className="absolute -left-[1.35rem] top-6 hidden h-3 w-3 rounded-full border border-violet-400/40 bg-violet-500 sm:block" />
                        <div className="flex items-start justify-between gap-4">
                          <div className="min-w-0 flex-1">
                            <div className="flex flex-wrap items-center gap-2">
                              <Badge>{entry.reflection.mood}</Badge>
                              <span className="text-xs text-zinc-500">
                                Intensity {entry.reflection.emotionalIntensity}/10
                              </span>
                            </div>
                            <p className="mt-3 line-clamp-2 text-sm leading-relaxed text-zinc-300">
                              {getEntryPreviewLine(entry.reflection)}
                            </p>
                            <div className="mt-4 flex flex-wrap items-center gap-3 text-xs text-zinc-500">
                              <span className="inline-flex items-center gap-1">
                                <Clock3 className="h-3.5 w-3.5" />
                                {entry.durationSeconds}s
                              </span>
                              <span>{formatRelativeDate(entry.createdAt)}</span>
                              <span className="hidden sm:inline">
                                {formatEntryDate(entry.createdAt)}
                              </span>
                            </div>
                          </div>
                          <ArrowRight className="mt-1 h-4 w-4 shrink-0 text-zinc-600 transition-transform group-hover:translate-x-0.5 group-hover:text-violet-300" />
                        </div>
                      </CardContent>
                    </Card>
                  </Link>
                </motion.div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
