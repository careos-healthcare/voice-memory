"use client";

import { useMemo } from "react";

import { buildArchiveOpenQuestions } from "@/lib/archive/archive-open-question";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveOpenQuestionProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
  limit?: number;
};

export function ArchiveOpenQuestion({
  entriesOverride,
  className,
  limit = 2,
}: ArchiveOpenQuestionProps) {
  const hydrated = useClientHydrated();
  const questions = useMemo(() => {
    if (!hydrated) return [];
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    return buildArchiveOpenQuestions(entries).slice(0, limit);
  }, [hydrated, entriesOverride, limit]);

  if (questions.length === 0) return null;

  return (
    <div className={cn("space-y-3", className)} data-testid="archive-open-question">
      {questions.map((q) => (
        <div
          key={q.id}
          className="rounded-xl border border-dashed border-white/10 bg-black/20 px-4 py-3"
        >
          <p className={ARCHIVE_TYPO.caption}>{q.lead}</p>
          <p className={cn(ARCHIVE_TYPO.body, "mt-1 text-zinc-300")}>{q.text}</p>
        </div>
      ))}
    </div>
  );
}
