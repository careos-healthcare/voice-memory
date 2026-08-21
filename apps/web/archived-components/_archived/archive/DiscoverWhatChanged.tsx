"use client";

import { useMemo } from "react";

import { ArchiveWatchCard } from "@/archived-components/_archived/archive/ArchiveWatchCard";
import { buildArchiveActivityView } from "@/lib/archive/archive-activity";
import { buildArchiveStateObject } from "@/lib/archive/archive-state-object";
import {
  DISCOVER_CHANGES_TITLE,
  DISCOVER_EVIDENCE_ADDED,
  DISCOVER_WATCH_TITLE,
} from "@/lib/archive/archive-disclosure-copy";
import { ARCHIVE_V3_WHAT_CHANGED } from "@/lib/archive/archive-reduction-v3-copy";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

type DiscoverWhatChangedProps = {
  entriesOverride?: JournalEntry[];
};

function ChangeList({
  title,
  items,
  testId,
}: {
  title: string;
  items: { id: string; text: string }[];
  testId: string;
}) {
  if (items.length === 0) return null;
  return (
    <section data-testid={testId} className="space-y-2">
      <h2 className={ARCHIVE_TYPO.sectionTitle}>{title}</h2>
      <ul className="space-y-2">
        {items.map((item) => (
          <li key={item.id} className={ARCHIVE_TYPO.body}>
            {item.text}
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Discover — belief changes, new evidence, watch only. */
export function DiscoverWhatChanged({ entriesOverride }: DiscoverWhatChangedProps) {
  const hydrated = useClientHydrated();
  const entries = entriesOverride ?? getMemoryEligibleEntries();

  const state = useMemo(
    () => (hydrated ? buildArchiveStateObject(entries) : null),
    [hydrated, entries],
  );

  const activity = useMemo(
    () => (hydrated ? buildArchiveActivityView(entries) : null),
    [hydrated, entries],
  );

  if (!hydrated || !state) return null;

  const hasActivity =
    (activity?.beliefChanges.length ?? 0) > 0 ||
    (activity?.evidenceChanges.length ?? 0) > 0;

  return (
    <div className="space-y-8" data-testid="discover-what-changed">
      <section data-testid="discover-summary-changed">
        <h2 className={ARCHIVE_TYPO.sectionTitle}>{DISCOVER_CHANGES_TITLE}</h2>
        <p className={`${ARCHIVE_TYPO.body} mt-2 text-zinc-300`}>{state.changeSummary}</p>
      </section>

      {hasActivity ? (
        <>
          <ChangeList
            title={ARCHIVE_V3_WHAT_CHANGED}
            items={activity!.beliefChanges}
            testId="discover-belief-changes"
          />
          <ChangeList
            title={DISCOVER_EVIDENCE_ADDED}
            items={activity!.evidenceChanges}
            testId="discover-new-evidence"
          />
        </>
      ) : null}

      <section data-testid="discover-watch">
        <h2 className={`${ARCHIVE_TYPO.sectionTitle} mb-2`}>{DISCOVER_WATCH_TITLE}</h2>
        <ArchiveWatchCard watchItem={state.watchItem} />
      </section>
    </div>
  );
}
