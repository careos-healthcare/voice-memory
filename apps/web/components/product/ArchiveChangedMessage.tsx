"use client";

import { useMemo } from "react";

import { buildArchiveChangedMessage } from "@/lib/product/archive-value-progress";
import { pickPostSaveEvolvingNote } from "@/lib/product/evolving-understanding-copy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

interface ArchiveChangedMessageProps {
  entriesOverride?: JournalEntry[];
  className?: string;
}

export function ArchiveChangedMessage({
  entriesOverride,
  className = "",
}: ArchiveChangedMessageProps) {
  const { message, evolvingNote } = useMemo(() => {
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    const count = entries.filter((e) => e.reflectionPending !== true).length;
    return {
      message: buildArchiveChangedMessage(entriesOverride),
      evolvingNote: pickPostSaveEvolvingNote(count),
    };
  }, [entriesOverride]);

  if (!message) return null;

  return (
    <div className={className} data-testid="archive-changed-message">
      <p className="text-sm leading-relaxed text-emerald-200/90">{message}</p>
      {evolvingNote ? (
        <p className="mt-2 text-xs leading-relaxed text-zinc-500">{evolvingNote}</p>
      ) : null}
    </div>
  );
}
