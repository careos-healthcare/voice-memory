import { ARCHIVE_MATURITY_TAGLINE } from "@/lib/archive/archive-maturity-copy";
import {
  buildArchiveProgressView,
} from "@/lib/archive/archive-maturity-engine";
import type { ArchiveMaturityView } from "@/types/archive-maturity";
import type { JournalEntry } from "@/types/journal";

/** @deprecated prefer buildArchiveProgressView — kept for legacy callers. */
export function buildArchiveMaturityView(
  entriesInput?: JournalEntry[],
): ArchiveMaturityView {
  const progress = buildArchiveProgressView(entriesInput);
  return {
    stage: progress.stage,
    stageLabel: progress.stageLabel,
    percent: progress.score,
    tagline: ARCHIVE_MATURITY_TAGLINE,
  };
}
