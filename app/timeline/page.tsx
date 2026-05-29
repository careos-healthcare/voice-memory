"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CalendarRange } from "lucide-react";

import { ReturnThreadsOverview } from "@/components/continuity/ReturnThreadsOverview";
import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";
import { OpenLoopsSection } from "@/components/open-loops/OpenLoopsSection";
import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { BookmarkIndicator } from "@/components/memory/ReflectionBookmarkMark";
import { RevisitEntryLink } from "@/components/navigation/RevisitEntryLink";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { followupPromptFromReturnThreads } from "@/lib/continuity/followup-from-threads";
import {
  buildRecordReturnFromFollowup,
  storeRecordReturnContext,
} from "@/lib/reflection/record-return";
import { useBookmarkedEntryIds } from "@/lib/hooks/useReflectionBookmark";
import { orderEntriesForRevisitPrompts } from "@/lib/refinement/revisit-worth";
import { getAllEntries, getMemoryEligibleEntries } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { ReturnThreadsReport } from "@/types/return-thread";

export default function TimelinePage() {
  const router = useRouter();
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [report, setReport] = useState<ReturnThreadsReport | null>(null);
  const bookmarkedIds = useBookmarkedEntryIds();

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const allEntries = getAllEntries();
      const memoryEntries = getMemoryEligibleEntries();
      setEntries(allEntries);
      setReport(buildReturnThreads(memoryEntries));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const reflectionEntries = useMemo(() => {
    const eligible = entries.filter((entry) => entry.reflectionPending !== true);
    return orderEntriesForRevisitPrompts(eligible, 12);
  }, [entries]);

  const followupPrompt = useMemo(
    () => followupPromptFromReturnThreads(report, entries),
    [report, entries],
  );

  const handleRecordAgain = (prompt: FollowupPrompt) => {
    storeRecordReturnContext(buildRecordReturnFromFollowup(prompt));
    router.push("/#recorder");
  };

  const loading = report === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-4">
        <MotionPageTitle title="Over time" />
        <p className="mt-3 text-sm leading-relaxed text-muted">
          What keeps returning, what changed, and what stayed unresolved — in your
          own words.
        </p>

        <div className="mt-6 flex flex-wrap gap-3 text-sm">
          <Link href="/open-loops" className="text-muted hover:text-zinc-200">
            Open loops →
          </Link>
        </div>

        <div className="mt-10 space-y-12">
          {loading ? (
            <p className="py-20 text-center text-sm text-muted" role="status">One moment…</p>
          ) : entries.length === 0 ? (
            <AnticipatoryEmptyState
              icon={<CalendarRange className="h-6 w-6 text-violet-300" />}
            />
          ) : (
            <>
              <OpenLoopsSection maxItems={2} />
              <ReturnThreadsOverview report={report ?? undefined} />

              <FollowupPromptInline
                prompt={followupPrompt}
                onRecordAgain={handleRecordAgain}
              />

              <section className="space-y-4 border-t border-white/5 pt-8">
                <h2 className="text-xs font-normal tracking-wide text-muted">
                  Reflections
                </h2>
                <ul className="space-y-2">
                  {reflectionEntries.map((entry) => (
                    <li key={entry.id}>
                      <RevisitEntryLink
                        entryId={entry.id}
                        source="timeline"
                        className="flex items-center gap-3 px-1 py-3 text-sm text-muted transition-colors hover:text-zinc-200"
                      >
                        <span>{formatEntryDate(entry.createdAt)}</span>
                        <BookmarkIndicator
                          entryId={entry.id}
                          bookmarkedIds={bookmarkedIds}
                        />
                      </RevisitEntryLink>
                    </li>
                  ))}
                </ul>
                {entries.filter((entry) => entry.reflectionPending !== true).length > 12 ? (
                  <Button asChild variant="ghost" size="sm" className="text-muted">
                    <Link href="/journal">All reflections</Link>
                  </Button>
                ) : null}
              </section>
            </>
          )}
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
