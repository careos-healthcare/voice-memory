"use client";

import { useMemo } from "react";

import { ArchiveOpenQuestion } from "@/archived-components/_archived/archive/ArchiveOpenQuestion";
import { buildArchiveActivityView } from "@/lib/archive/archive-activity";
import { ARCHIVE_ACTIVITY_SECTION } from "@/lib/archive/living-archive-copy";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

type ArchiveActivityPanelProps = {
  entriesOverride?: JournalEntry[];
};

function ActivitySection({
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

/** Archive Activity — living archive sections, not movement feed cards. */
export function ArchiveActivityPanel({ entriesOverride }: ArchiveActivityPanelProps) {
  const hydrated = useClientHydrated();
  const activity = useMemo(
    () =>
      hydrated
        ? buildArchiveActivityView(entriesOverride ?? getMemoryEligibleEntries())
        : null,
    [hydrated, entriesOverride],
  );

  if (!activity) return null;

  const hasContent =
    activity.statusChanges.length > 0 ||
    activity.beliefChanges.length > 0 ||
    activity.evidenceChanges.length > 0 ||
    activity.openQuestions.length > 0;

  if (!hasContent) return null;

  return (
    <div className="space-y-8" data-testid="archive-activity-panel">
      <ActivitySection
        title={ARCHIVE_ACTIVITY_SECTION.statusChanges}
        items={activity.statusChanges}
        testId="archive-activity-status-changes"
      />
      <ActivitySection
        title={ARCHIVE_ACTIVITY_SECTION.beliefChanges}
        items={activity.beliefChanges}
        testId="archive-activity-belief-changes"
      />
      <ActivitySection
        title={ARCHIVE_ACTIVITY_SECTION.evidenceChanges}
        items={activity.evidenceChanges}
        testId="archive-activity-evidence-changes"
      />
      {activity.openQuestions.length > 0 ? (
        <section data-testid="archive-activity-open-questions" className="space-y-2">
          <h2 className={ARCHIVE_TYPO.sectionTitle}>{ARCHIVE_ACTIVITY_SECTION.openQuestions}</h2>
          <ArchiveOpenQuestion entriesOverride={entriesOverride} limit={3} />
        </section>
      ) : null}
    </div>
  );
}
