"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { BookOpen } from "lucide-react";

import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { FirstReturnMoment } from "@/components/continuity/FirstReturnMoment";
import { JournalArchiveRow } from "@/components/journal/JournalArchiveRow";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { RECOGNITION_COPY } from "@/lib/product/recognition-copy";
import { isPrimarySurfacedReflection } from "@/lib/reflection/reflection-quality-gate";
import { getEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export default function JournalPage() {
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const surfacedEntries = entries.filter(isPrimarySurfacedReflection);

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
              <h1 className="text-3xl font-semibold text-white">Journal</h1>
              <p className="mt-2 text-sm text-zinc-500">{RECOGNITION_COPY.journalLead}</p>
            </div>
            <Button asChild variant="secondary" size="sm">
              <Link href="/record">Record</Link>
            </Button>
          </div>
        </motion.div>

        <div className="mt-10">
          {loading ? (
            <div className="space-y-3">
              {[1, 2, 3].map((item) => (
                <Skeleton key={item} className="h-16 w-full" />
              ))}
            </div>
          ) : surfacedEntries.length === 0 ? (
            <AnticipatoryEmptyState
              entryCount={entries.length}
              icon={<BookOpen className="h-6 w-6 text-violet-300" />}
            />
          ) : (
            <>
              <FirstReturnMoment entries={entries} className="mb-12" />

              <div className="space-y-1">
                <p className="mb-4 px-1 text-[10px] uppercase tracking-[0.2em] text-zinc-700">
                  What you said
                </p>
                <div className="space-y-2">
                  {surfacedEntries.map((entry, index) => (
                    <motion.div
                      key={entry.id}
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.03 }}
                    >
                      <JournalArchiveRow entry={entry} />
                    </motion.div>
                  ))}
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
