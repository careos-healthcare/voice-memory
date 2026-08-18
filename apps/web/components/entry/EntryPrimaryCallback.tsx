"use client";

import { useMemo } from "react";

import { MemoryConfidence } from "@/components/system/MemoryConfidence";
import { runCanonicalPipelineForMemoryNote } from "@/lib/resurfacing/canonical-resurfacing-pipeline";
import { recordResurfacingFeedback } from "@/lib/resurfacing/resurfacing-feedback";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

function quoteFromNote(note: MemoryNote): string {
  const q = note.currentQuote?.trim() || note.pastQuote?.trim();
  if (q) return q.startsWith('"') ? q : `"${q}"`;
  return note.text.trim();
}

export function EntryPrimaryCallback({
  note,
  entries: entriesProp,
  className,
}: {
  note: MemoryNote;
  entries?: JournalEntry[];
  className?: string;
}) {
  const entries = entriesProp ?? getMemoryEligibleEntries();
  const result = useMemo(
    () => runCanonicalPipelineForMemoryNote(note, entries),
    [note, entries],
  );

  if (!result.show) return null;

  const quote = quoteFromNote(note);
  if (!quote) return null;

  const uncertain =
    result.safeDisplayMode === "cautious" || result.safeDisplayMode === "change";

  const subline =
    result.safeDisplayMode === "change" && result.evidence.emotionalShift
      ? result.evidence.emotionalShift
      : uncertain
        ? undefined
        : result.callbackText;

  return (
    <section
      className={`rounded-2xl border border-violet-400/15 bg-violet-500/[0.06] px-5 py-6 ${className ?? ""}`}
      aria-label="Memory callback"
    >
      <MemoryConfidence
        quote={quote}
        subline={subline}
        whySurfaced={result.whySurfacedLines[0] ?? note.evidenceReason}
        confidenceLabel={
          uncertain ? "We are less sure about this connection" : undefined
        }
        onFeedback={(kind) => {
          recordResurfacingFeedback({
            kind,
            quote,
            surface: "callback",
          });
        }}
      />
    </section>
  );
}
