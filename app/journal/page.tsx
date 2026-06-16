"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { BookOpen } from "lucide-react";

import { ArchiveProductWayfinding } from "@/components/archive/ArchiveProductWayfinding";
import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { FirstReturnMoment } from "@/components/continuity/FirstReturnMoment";
import { JournalArchiveRow } from "@/components/journal/JournalArchiveRow";
import { JournalSyncStatus } from "@/components/journal/JournalSyncStatus";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { LoadingState, PrivacyNotice } from "@/components/system";
import { Button } from "@/components/ui/button";
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

        <PrimaryMain className="mt-4">
        <ArchiveProductWayfinding variant="journal" className="mb-4" />
        <div>
          <div className="flex flex-wrap items-end justify-between gap-4">
            <MotionPageTitle title="Journal" className="mt-0" />
            <Button asChild variant="secondary" size="sm" className="mobile-touch-target shrink-0">
              <Link href="/record">Record</Link>
            </Button>
          </div>
          <p className="mt-2 text-sm text-muted">{RECOGNITION_COPY.journalLead}</p>
          <div className="mt-3 space-y-3">
            <JournalSyncStatus />
            <PrivacyNotice />
          </div>
        </div>

        <div className="mt-10">
          {loading ? (
            <LoadingState lines={5} label="Loading journal" />
          ) : surfacedEntries.length === 0 ? (
            <AnticipatoryEmptyState
              entryCount={entries.length}
              icon={<BookOpen className="h-6 w-6 text-violet-300" />}
            />
          ) : (
            <>
              <FirstReturnMoment entries={entries} className="mb-12" />

              <div className="space-y-1">
                <p className="mb-4 px-1 text-[10px] uppercase tracking-[0.2em] text-zinc-500">
                  What you said
                </p>
                <ul className="space-y-2">
                  {surfacedEntries.map((entry) => (
                    <li key={entry.id}>
                      <JournalArchiveRow entry={entry} />
                    </li>
                  ))}
                </ul>
              </div>
            </>
          )}
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
