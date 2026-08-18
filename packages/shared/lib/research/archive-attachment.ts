import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildArchiveLandmarkReport } from "@/lib/archive/archive-landmarks";
import { LAUNCH_EVENTS, countLocalEvents, readLocalEvents } from "@/lib/local-analytics";
import {
  REMEMBERED_LATER_COPIED_REOPENED,
  REMEMBERED_LATER_DELAYED_REVISIT,
} from "@/lib/social-proof/remembered-later";
import { buildRetentionLoopReport, readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { readStoredIncidents } from "@/lib/validation/incidents";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  ArchiveAttachmentKind,
  ArchiveAttachmentReport,
  ArchiveAttachmentSignal,
} from "@/types/validation-ops";

function signal(
  kind: ArchiveAttachmentKind,
  label: string,
  detail: string,
  strength: number,
  entryId?: string,
): ArchiveAttachmentSignal {
  return {
    id: `attach-${kind}-${entryId ?? label.slice(0, 12)}`,
    kind,
    label,
    detail,
    entryId,
    strength,
  };
}

function oldestRevisited(entries: JournalEntry[]): ArchiveAttachmentSignal | null {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const oldest = sorted[0];
  if (!oldest) return null;

  const revisited = readRetentionLoopEvents().some(
    (event) =>
      (event.entryId === oldest.id || event.targetEntryId === oldest.id) &&
      event.kind === "entry_revisited",
  );

  if (!revisited) return null;

  return signal(
    "oldest_revisited",
    "Oldest entry revisited",
    `First reflection from ${oldest.createdAt.slice(0, 10)} was reopened`,
    82,
    oldest.id,
  );
}

function reopenChains(): ArchiveAttachmentSignal[] {
  const loops = buildRetentionLoopReport();
  const chains: ArchiveAttachmentSignal[] = [];

  for (const note of loops.notesCausingRevisits.filter((n) => n.oldEntryOpens >= 2)) {
    chains.push(
      signal(
        "reopen_chain",
        "Repeated reopen chain",
        `${note.oldEntryOpens} opens · ${note.clicks} clicks`,
        70 + note.oldEntryOpens * 4,
        note.noteId,
      ),
    );
  }

  return chains.slice(0, 4);
}

function copiedCallbackReopened(): ArchiveAttachmentSignal[] {
  const events = readLocalEvents().filter((e) => e.name === REMEMBERED_LATER_COPIED_REOPENED);
  return events.slice(-4).map((event) =>
    signal(
      "copied_callback_reopened",
      "Copied callback reopened later",
      event.meta?.noteText || event.meta?.callbackId || "Copied moment reopened",
      78,
      event.meta?.entryId,
    ),
  );
}

function reflectionsRevisitedMonthsLater(entries: JournalEntry[]): ArchiveAttachmentSignal[] {
  const loops = buildRetentionLoopReport();
  const results: ArchiveAttachmentSignal[] = [];

  for (const link of loops.revisitsCausingReflections.filter((l) => l.reflectionEntryId)) {
    const original = entries.find((e) => e.id === link.entryId);
    const reflection = entries.find((e) => e.id === link.reflectionEntryId);
    if (!original || !reflection) continue;

    const spanDays = daysBetweenKeys(
      toDayKey(original.createdAt),
      toDayKey(reflection.createdAt),
    );
    if (spanDays < 60) continue;

    results.push(
      signal(
        "reflection_revisited_months_later",
        "Reflection after months",
        `${Math.floor(spanDays / 30)} months between revisit and reflection`,
        Math.min(95, 60 + spanDays / 10),
        link.entryId,
      ),
    );
  }

  return results.slice(0, 3);
}

function exportBeforeDeletion(): ArchiveAttachmentSignal | null {
  const exports = countLocalEvents(LAUNCH_EVENTS.exportUsed);
  const deletionIncidents = readStoredIncidents().filter(
    (row) => row.detail.toLowerCase().includes("delet") || row.kind === "failed_restore",
  );

  if (exports === 0 || deletionIncidents.length === 0) return null;

  return signal(
    "export_before_deletion",
    "Exported before deletion attempt",
    `${exports} export(s) recorded near archive deletion/restore events`,
    74,
  );
}

function restoreAfterReinstall(): ArchiveAttachmentSignal | null {
  const restores = readStoredIncidents().filter((row) => row.kind === "failed_restore");
  const entries = getMemoryEligibleEntries();

  if (entries.length < 3) return null;

  const restore = restores.sort(
    (a, b) => new Date(b.detectedAt).getTime() - new Date(a.detectedAt).getTime(),
  )[0];

  if (!restore) return null;

  return signal(
    "restore_after_reinstall",
    "Restore after reinstall",
    `Archive restored on ${restore.detectedAt.slice(0, 10)} — ${entries.length} entries present`,
    80,
  );
}

/** Detect whether the archive is becoming personally irreplaceable. */
export function buildArchiveAttachmentReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ArchiveAttachmentReport {
  const landmarks = buildArchiveLandmarkReport(entries);
  const signals: ArchiveAttachmentSignal[] = [];

  const oldest = oldestRevisited(entries);
  if (oldest) signals.push(oldest);

  for (const landmark of landmarks.landmarks) {
    signals.push(
      signal(
        "durable_landmark",
        landmark.text,
        landmark.evidence,
        landmark.strength,
        landmark.entryId,
      ),
    );
  }

  signals.push(...reopenChains());
  signals.push(...copiedCallbackReopened());
  signals.push(...reflectionsRevisitedMonthsLater(entries));

  const delayedRevisits = readLocalEvents().filter(
    (e) => e.name === REMEMBERED_LATER_DELAYED_REVISIT,
  );
  for (const event of delayedRevisits.slice(-2)) {
    signals.push(
      signal(
        "reflection_revisited_months_later",
        "Delayed revisit recorded",
        event.meta?.callbackId || "Callback revisited after delay",
        76,
        event.meta?.entryId,
      ),
    );
  }

  const exportSignal = exportBeforeDeletion();
  if (exportSignal) signals.push(exportSignal);

  const restoreSignal = restoreAfterReinstall();
  if (restoreSignal) signals.push(restoreSignal);

  const unique = signals
    .filter((row, index, arr) => arr.findIndex((r) => r.id === row.id) === index)
    .sort((a, b) => b.strength - a.strength);

  const attachmentScore = Math.min(
    100,
    Math.round(unique.reduce((sum, row) => sum + row.strength, 0) / Math.max(unique.length, 1)),
  );

  return {
    generatedAt: new Date().toISOString(),
    hasData: unique.length > 0,
    signals: unique.slice(0, 12),
    attachmentScore,
    irreplaceable: attachmentScore >= 65 && unique.length >= 3,
  };
}
