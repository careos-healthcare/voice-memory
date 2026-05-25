import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import {
  LAUNCH_EVENTS,
  PHOTO_EVENTS,
  countLocalEvents,
  readLocalEvents,
} from "@/lib/local-analytics";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import {
  REMEMBERED_LATER_DELAYED_REVISIT,
  REMEMBERED_LATER_DELAYED_REFLECTION,
} from "@/lib/social-proof/remembered-later";
import { buildEmotionalTerritoriesReport } from "@/lib/territories/emotional-territories";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveAttachmentLevel } from "@/types/first-week-retention";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveAttachmentSignalRow {
  id: string;
  label: string;
  weight: number;
}

export interface ArchiveAttachmentAssessment {
  level: ArchiveAttachmentLevel;
  score: number;
  signals: ArchiveAttachmentSignalRow[];
  evidenceLines: string[];
}

function revisitCountForEntry(entryId: string): number {
  return readRetentionLoopEvents().filter(
    (event) =>
      event.kind === "entry_revisited" &&
      (event.entryId === entryId || event.targetEntryId === entryId),
  ).length;
}

function exportViewCount(): number {
  return countLocalEvents(LAUNCH_EVENTS.exportUsed);
}

/** Internal strength only — never shown as a user-facing score. */
export function assessArchiveAttachment(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ArchiveAttachmentAssessment {
  const signals: ArchiveAttachmentSignalRow[] = [];
  const events = readLocalEvents();
  const loops = readRetentionLoopEvents();

  const rereadTotal = loops.filter((e) => e.kind === "entry_revisited").length;
  if (rereadTotal >= 1) {
    signals.push({ id: "rereads", label: "Entry rereads", weight: 12 + rereadTotal * 4 });
  }
  if (rereadTotal >= 3) {
    signals.push({ id: "rereads_sustained", label: "Sustained rereads", weight: 18 });
  }

  const copies = loops.filter((e) => e.kind === "copied_memory_moment").length;
  if (copies >= 1) {
    signals.push({ id: "copied_lines", label: "Copied lines", weight: 14 + copies * 3 });
  }

  const photoRevisits = events.filter((e) => e.name === PHOTO_EVENTS.entryRevisited).length;
  if (photoRevisits >= 1) {
    signals.push({ id: "photo_revisit", label: "Photo revisit", weight: 16 });
  }

  const delayedReflections = events.filter(
    (e) => e.name === REMEMBERED_LATER_DELAYED_REFLECTION,
  ).length;
  if (delayedReflections >= 1) {
    signals.push({ id: "delayed_reflection", label: "Delayed reflection", weight: 20 });
  }

  const delayedRevisits = events.filter((e) => e.name === REMEMBERED_LATER_DELAYED_REVISIT).length;
  if (delayedRevisits >= 1) {
    signals.push({ id: "delayed_revisit", label: "Delayed revisit", weight: 18 });
  }

  const territoryReport = buildEmotionalTerritoriesReport(entries);
  const territoryRevisits = territoryReport.territories.filter((t) => t.entryIds.length >= 2).length;
  if (territoryRevisits >= 1) {
    signals.push({
      id: "territory_forming",
      label: "Territory forming",
      weight: 15 + territoryRevisits * 2,
    });
  }

  if (exportViewCount() >= 1) {
    signals.push({ id: "export_view", label: "Export viewed", weight: 22 });
  }

  const rememberedCallbacks = events.filter((e) =>
    e.name.startsWith("remembered_later"),
  ).length;
  if (rememberedCallbacks >= 1) {
    signals.push({ id: "callback_landed", label: "Callback landed", weight: 12 });
  }

  for (const entry of entries.slice(0, 8)) {
    const count = revisitCountForEntry(entry.id);
    if (count >= 2) {
      signals.push({
        id: `repeat_${entry.id}`,
        label: "Repeat return to entry",
        weight: 10 + count * 3,
      });
      break;
    }
  }

  const score = Math.min(100, signals.reduce((sum, row) => sum + row.weight, 0));
  let level: ArchiveAttachmentLevel = "weak";
  if (score >= 52) level = "strong";
  else if (score >= 24) level = "emerging";

  const evidenceLines = signals.slice(0, 6).map((s) => s.label);

  return { level, score, signals, evidenceLines };
}

export function isWithinFirstWeekOfArchive(entries: JournalEntry[]): boolean {
  if (entries.length === 0) return true;
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const first = sorted[0];
  return daysBetweenKeys(toDayKey(first.createdAt), todayKey()) <= 7;
}
