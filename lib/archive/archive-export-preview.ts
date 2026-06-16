import { buildBeliefChangeTimeline } from "@/lib/archive/belief-timeline";
import { buildBeliefDossier } from "@/lib/archive/belief-dossier";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { buildArchiveWorthSnapshot } from "@/lib/archive/archive-worth";
import { readBeliefRecallRecords } from "@/lib/retention/belief-recall";
import { readArchiveAttachmentRecords } from "@/lib/archive/archive-attachment";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveExportPreviewSection {
  id: string;
  label: string;
  detail: string;
}

export interface ArchiveExportPreview {
  lead: string;
  sections: ArchiveExportPreviewSection[];
}

export function buildArchiveExportPreview(
  entriesInput?: JournalEntry[],
): ArchiveExportPreview {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const worth = buildArchiveWorthSnapshot(entries);
  const locker = buildEvidenceLocker(entries);
  const dossier = buildBeliefDossier(entries);
  const timeline = dossier
    ? buildBeliefChangeTimeline(entries, { theoryId: dossier.theoryId })
    : null;
  const recallCount = readBeliefRecallRecords().length;
  const attachmentCount = readArchiveAttachmentRecords().length;

  const sections: ArchiveExportPreviewSection[] = [
    {
      id: "reflections",
      label: "Reflections",
      detail: worth
        ? `${worth.reflectionCount} on device`
        : `${entries.filter((e) => e.reflectionPending !== true).length} on device`,
    },
    {
      id: "beliefs",
      label: "Current beliefs & dossier",
      detail: dossier ? "Lead belief case file included" : "Not enough data yet",
    },
    {
      id: "timeline",
      label: "Belief timeline",
      detail: timeline
        ? `${timeline.points.length} point${timeline.points.length === 1 ? "" : "s"}`
        : "—",
    },
    {
      id: "locker",
      label: "Evidence locker",
      detail: `${locker.items.length} top quote${locker.items.length === 1 ? "" : "s"}`,
    },
    {
      id: "markers",
      label: "Attachment & recall markers",
      detail: `${attachmentCount} attachment · ${recallCount} recall`,
    },
  ];

  return {
    lead: "Take your evidence trail with you.",
    sections,
  };
}
