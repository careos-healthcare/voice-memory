import { buildArchiveActivityView } from "@/lib/archive/archive-activity";
import { buildArchiveMemory } from "@/lib/archive/archive-memory";
import { buildArchiveOpenQuestions } from "@/lib/archive/archive-open-question";
import { buildArchivePulse } from "@/lib/archive/archive-pulse";
import { buildArchiveReasonToReturn } from "@/lib/archive/archive-reason-to-return";
import { buildArchiveStatusView } from "@/lib/archive/archive-status";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { LivingArchiveView } from "@/types/living-archive";
import type { JournalEntry } from "@/types/journal";

export function buildLivingArchiveView(
  entriesInput?: JournalEntry[],
): LivingArchiveView {
  const entries = entriesInput ?? getMemoryEligibleEntries();

  return {
    status: buildArchiveStatusView(entries),
    pulse: buildArchivePulse(entries),
    memory: buildArchiveMemory(entries),
    openQuestions: buildArchiveOpenQuestions(entries),
    reasonToReturn: buildArchiveReasonToReturn(entries),
    activity: buildArchiveActivityView(entries),
  };
}
