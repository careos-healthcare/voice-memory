"use client";

import { useMemo } from "react";

import { ArchiveHealthLine } from "@/archived-components/_archived/archive/ArchiveHealthLine";
import { ArchiveWatchCard } from "@/archived-components/_archived/archive/ArchiveWatchCard";
import { buildArchiveStateObject } from "@/lib/archive/archive-state-object";
import {
  ARCHIVE_V3_CURRENT_BELIEF,
  ARCHIVE_V3_WHAT_CHANGED,
  ARCHIVE_V3_WHY,
} from "@/lib/archive/archive-reduction-v3-copy";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveReductionV3HomeProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

function V3Section({
  title,
  body,
  testId,
  className = "",
}: {
  title: string;
  body: string;
  testId: string;
  className?: string;
}) {
  return (
    <section
      className={cn("rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4", className)}
      data-testid={testId}
    >
      <h2 className={ARCHIVE_TYPO.sectionTitle}>{title}</h2>
      <p className={`${ARCHIVE_TYPO.body} mt-2 text-zinc-200`}>{body}</p>
    </section>
  );
}

/** Archive home — four user-facing sections + one health line. */
export function ArchiveReductionV3Home({
  entriesOverride,
  className = "",
}: ArchiveReductionV3HomeProps) {
  const hydrated = useClientHydrated();

  const state = useMemo(
    () => (hydrated ? buildArchiveStateObject(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!state) return null;

  return (
    <div
      className={cn("space-y-4", ARCHIVE_SPACE.sectionBreath, className)}
      data-testid="archive-reduction-v3-home"
    >
      <header
        className="rounded-2xl border border-violet-500/40 bg-gradient-to-br from-violet-950/55 via-zinc-950/90 to-zinc-950 px-4 py-4"
        data-testid="archive-v3-current-belief"
      >
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-violet-300/90">
          {ARCHIVE_V3_CURRENT_BELIEF}
        </p>
        <p className="mt-3 text-lg font-medium leading-snug text-zinc-50 sm:text-xl">
          {state.belief}
        </p>
      </header>

      <V3Section
        title={ARCHIVE_V3_WHY}
        body={state.evidenceSummary}
        testId="archive-v3-why"
      />
      <V3Section
        title={ARCHIVE_V3_WHAT_CHANGED}
        body={state.changeSummary}
        testId="archive-v3-what-changed"
      />
      <ArchiveWatchCard watchItem={state.watchItem} />
      <ArchiveHealthLine health={state.health} />
    </div>
  );
}
