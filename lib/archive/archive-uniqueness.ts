import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

import { ARCHIVE_UNIQUENESS_STATIC_BULLETS } from "@/lib/archive/archive-uniqueness-copy";

export interface ArchiveUniquenessView {
  staticBullets: readonly string[];
  dynamicLines: string[];
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

export function buildArchiveUniquenessView(
  entriesInput?: JournalEntry[],
): ArchiveUniquenessView {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const dynamicLines: string[] = [];

  const belief = buildArchiveBeliefView(entries);
  if (belief) {
    const survival = buildBeliefSurvivalView(entries, { theoryId: belief.theoryId });
    if (survival) {
      dynamicLines.push(
        `Current belief first appeared ${survival.firstAppearedDate} (${survival.daysAlive} days on record).`,
      );
      if (survival.contradictionsSurvived > 0) {
        dynamicLines.push(
          `Survived ${survival.contradictionsSurvived} challenge${survival.contradictionsSurvived === 1 ? "" : "s"} without dropping.`,
        );
      }
    }
    if (belief.evidence.lifeAreas.length >= 2) {
      dynamicLines.push(
        `Evidence spans ${belief.evidence.lifeAreas.slice(0, 3).join(", ").toLowerCase()}.`,
      );
    }
  }

  return {
    staticBullets: ARCHIVE_UNIQUENESS_STATIC_BULLETS,
    dynamicLines: dynamicLines.slice(0, 2),
  };
}
