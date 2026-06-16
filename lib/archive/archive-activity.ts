import { buildArchiveOpenQuestions } from "@/lib/archive/archive-open-question";
import { buildArchiveStatusView } from "@/lib/archive/archive-status";
import {
  ARCHIVE_LIVING_STATUS_LABEL,
  ARCHIVE_LIVING_STATUS_LINE,
} from "@/lib/archive/living-archive-copy";
import { buildArchiveStateDelta, readArchiveDeltaHistory } from "@/lib/archive/archive-state-snapshot";
import { buildEvidenceFeed } from "@/lib/discover/evidence-feed";
import { buildTheoryChangeFeed } from "@/lib/discover/theory-change-feed";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveActivityItem, ArchiveActivityView } from "@/types/living-archive";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function item(id: string, text: string): ArchiveActivityItem {
  return { id, text };
}

export function buildArchiveActivityView(
  entriesInput?: JournalEntry[],
): ArchiveActivityView {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const statusChanges: ArchiveActivityItem[] = [];
  const beliefChanges: ArchiveActivityItem[] = [];
  const evidenceChanges: ArchiveActivityItem[] = [];

  const currentStatus = buildArchiveStatusView(entries);
  const delta = buildArchiveStateDelta(entries);

  if (delta?.hasChanges) {
    statusChanges.push(
      item(
        "status-now",
        `${ARCHIVE_LIVING_STATUS_LABEL[currentStatus.status]} — ${currentStatus.line}`,
      ),
    );
  }

  for (const history of readArchiveDeltaHistory().slice(0, 3)) {
    if (!history.delta.hasChanges) continue;
    const rep = history.delta.rows.find((r) => r.kind === "reputation");
    if (rep) {
      statusChanges.push(item(history.id, `Reputation shifted: ${rep.difference}`));
    }
  }

  const feed = buildTheoryChangeFeed(entries);
  for (const group of [
    { title: "strengthened", items: feed.strengthened },
    { title: "weakened", items: feed.weakened },
    { title: "new", items: feed.new },
    { title: "resolved", items: feed.resolved },
  ]) {
    for (const change of group.items.slice(0, 4)) {
      const verb =
        change.category === "strengthened"
          ? "strengthened"
          : change.category === "weakened"
            ? "reconsidered"
            : change.category === "new"
              ? "formed"
              : "released";
      beliefChanges.push(
        item(
          `${change.category}-${change.theoryId}`,
          `The archive ${verb} a belief: ${change.statement.slice(0, 120)}`,
        ),
      );
    }
  }

  if (delta?.rows.length) {
    for (const row of delta.rows) {
      evidenceChanges.push(
        item(`delta-${row.kind}`, `The archive noted ${row.label.toLowerCase()}: ${row.difference}`),
      );
    }
  } else {
    const evidence = buildEvidenceFeed(entries);
    for (const row of evidence.movements.slice(0, 5)) {
      evidenceChanges.push(
        item(
          `${row.kind}-${row.theoryId}`,
          `The archive noted: ${row.summary}`,
        ),
      );
    }
  }

  const openQuestions = buildArchiveOpenQuestions(entries);

  return {
    statusChanges: statusChanges.slice(0, 6),
    beliefChanges: beliefChanges.slice(0, 8),
    evidenceChanges: evidenceChanges.slice(0, 6),
    openQuestions,
  };
}
