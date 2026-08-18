import { buildBeliefChangeTimeline } from "@/lib/archive/belief-timeline";
import { buildBeliefDossier } from "@/lib/archive/belief-dossier";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { buildArchiveWorthSnapshot } from "@/lib/archive/archive-worth";
import { readArchiveAttachmentRecords } from "@/lib/archive/archive-attachment";
import { readBeliefRecallRecords } from "@/lib/retention/belief-recall";
import type { JournalEntry } from "@/types/journal";

/** Serializable archive slice bundled into JSON export — reuses existing builders. */
export function buildArchiveExportAttachment(entries: JournalEntry[]) {
  const dossier = buildBeliefDossier(entries);
  return {
    worth: buildArchiveWorthSnapshot(entries),
    dossier,
    timeline: dossier
      ? buildBeliefChangeTimeline(entries, { theoryId: dossier.theoryId })
      : null,
    evidenceLocker: buildEvidenceLocker(entries),
    recallMarkers: readBeliefRecallRecords().slice(0, 40),
    attachmentMarkers: readArchiveAttachmentRecords().slice(0, 40),
  };
}
