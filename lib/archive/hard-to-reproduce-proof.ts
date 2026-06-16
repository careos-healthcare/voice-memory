import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface HardToReproduceProofLine {
  id: string;
  text: string;
}

export interface HardToReproduceProofView {
  lines: HardToReproduceProofLine[];
  theoryId?: string;
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

export function buildHardToReproduceProofView(
  entriesInput?: JournalEntry[],
): HardToReproduceProofView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length < 2) return null;

  const belief = buildArchiveBeliefView(entries);
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead = report.all[0];
  if (!lead) return null;

  const entryIds = new Set([
    ...lead.supportingEvidence.map((q) => q.entryId),
    ...lead.contradictingEvidence.map((q) => q.entryId),
  ]);
  const evidenceEntries = entries.filter((e) => entryIds.has(e.id));
  const reflectionCount = Math.max(entryIds.size, lead.supportingEvidenceCount);
  const sorted = [...evidenceEntries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const spanDays =
    sorted.length >= 2
      ? Math.max(
          1,
          daysBetweenKeys(toDayKey(sorted[0]!.createdAt), toDayKey(sorted[sorted.length - 1]!.createdAt)) +
            1,
        )
      : 1;

  const areas = linkedAreasForEntries(
    entries,
    [...entryIds],
  );
  const timelineChanges = readBeliefTimelineHistory(lead.id).length;
  const changeCount = Math.max(
    timelineChanges,
    lead.whatChanged?.length ?? 0,
    belief?.changeLines.length ?? 0,
  );

  const lines: HardToReproduceProofLine[] = [];

  lines.push({
    id: newId("htrp"),
    text: `This belief is based on ${reflectionCount} reflection${reflectionCount === 1 ? "" : "s"} across ${spanDays} day${spanDays === 1 ? "" : "s"}.`,
  });

  if (areas.length >= 2) {
    lines.push({
      id: newId("htrp"),
      text: `It includes evidence from ${areas.slice(0, 3).join(" and ").toLowerCase()}.`,
    });
  }

  if (changeCount >= 1) {
    lines.push({
      id: newId("htrp"),
      text:
        changeCount === 1
          ? "It changed once as new evidence arrived."
          : `It changed ${changeCount} times as new evidence arrived.`,
    });
  }

  lines.push({
    id: newId("htrp"),
    text: "This is hard to recreate from one prompt.",
  });

  return { lines, theoryId: lead.id };
}
