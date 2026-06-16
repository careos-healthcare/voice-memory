import { readArchiveDisclosureStorage } from "@/lib/archive/archive-disclosure-level";
import { buildArchiveMilestones } from "@/lib/archive/archive-milestones";
import {
  acknowledgeMilestone,
  dismissMilestoneReturnBanner,
  readAcknowledgedMilestoneId,
} from "@/lib/archive/archive-milestone-storage";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveMilestone } from "@/types/archive-milestone";
import type { JournalEntry } from "@/types/journal";

export function pickUnacknowledgedMilestone(
  entriesInput?: JournalEntry[],
): ArchiveMilestone | null {
  const visits = readArchiveDisclosureStorage().archiveVisitCount;
  if (visits < 2) return null;

  const view = buildArchiveMilestones(entriesInput);
  const latest = view.latest;
  if (!latest) return null;
  const ack = readAcknowledgedMilestoneId();
  if (ack === latest.id) return null;
  return latest;
}

export function acknowledgeLatestMilestone(entriesInput?: JournalEntry[]): void {
  const latest = buildArchiveMilestones(entriesInput).latest;
  if (latest) acknowledgeMilestone(latest.id);
}

export function dismissArchiveMilestoneReturn(): void {
  dismissMilestoneReturnBanner();
  const latest = buildArchiveMilestones().latest;
  if (latest) acknowledgeMilestone(latest.id);
}
