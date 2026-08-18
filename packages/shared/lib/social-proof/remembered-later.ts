import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { trackLocalEvent } from "@/lib/local-analytics";
import type { JournalEntry } from "@/types/journal";
import type { RememberedLaterReport, RememberedLaterRow } from "@/types/social-proof";

export const REMEMBERED_LATER_72H = "remembered_later_72h";
export const REMEMBERED_LATER_QUOTED = "remembered_later_quoted";
export const REMEMBERED_LATER_DELAYED_REVISIT = "remembered_later_delayed_revisit";
export const REMEMBERED_LATER_DELAYED_REFLECTION = "remembered_later_delayed_reflection";
export const REMEMBERED_LATER_COPIED_REOPENED = "remembered_later_copied_reopened";

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

export function trackRememberedLater72h(callbackId: string, noteText?: string): void {
  trackLocalEvent(REMEMBERED_LATER_72H, {
    callbackId,
    noteText: noteText?.slice(0, 120) ?? "",
  });
}

export function trackRememberedLaterQuoted(callbackId: string, noteText?: string): void {
  trackLocalEvent(REMEMBERED_LATER_QUOTED, {
    callbackId,
    noteText: noteText?.slice(0, 120) ?? "",
  });
}

export function trackRememberedLaterDelayedRevisit(callbackId: string, entryId: string): void {
  trackLocalEvent(REMEMBERED_LATER_DELAYED_REVISIT, { callbackId, entryId });
}

export function trackRememberedLaterDelayedReflection(
  callbackId: string,
  reflectionEntryId: string,
): void {
  trackLocalEvent(REMEMBERED_LATER_DELAYED_REFLECTION, { callbackId, reflectionEntryId });
}

export function trackRememberedLaterCopiedReopened(callbackId: string, entryId: string): void {
  trackLocalEvent(REMEMBERED_LATER_COPIED_REOPENED, { callbackId, entryId });
}

export function buildRememberedLaterReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RememberedLaterReport {
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const events = readRetentionLoopEvents();
  const sorted = sortedEntries(entries);

  const rows: RememberedLaterRow[] = callbackReport.items.map((item) => {
    const noteKeys = new Set([item.id, ...(item.sourceEntries?.map((e) => e.id) ?? [])]);
    const related = events.filter(
      (event) => event.noteId && noteKeys.has(event.noteId),
    );

    const delayedRevisit = related.some(
      (event) =>
        event.kind === "entry_revisited" ||
        event.kind === "old_entry_opened_from_note" ||
        event.kind === "resurfaced_memory_clicked",
    );
    const delayedReflection = related.some(
      (event) => event.kind === "followup_recording_completed",
    );
    const copiedReopened =
      related.some((event) => event.kind === "copied_memory_moment") &&
      related.some(
        (event) =>
          event.kind === "entry_revisited" || event.kind === "old_entry_opened_from_note",
      );

    return {
      callbackId: item.id,
      text: item.text,
      kind: item.kind,
      remembered72h: item.survival.remembered72hFlag || item.survival.remembered72hManual,
      quotedBack: item.manualLabels.includes("memorable") || item.manualLabels.includes("landed_emotionally"),
      delayedRevisit,
      delayedReflection,
      copiedReopened,
      score:
        (item.survival.remembered72hFlag || item.survival.remembered72hManual ? 30 : 0) +
        (delayedRevisit ? 20 : 0) +
        (delayedReflection ? 25 : 0) +
        (copiedReopened ? 15 : 0) +
        Math.round(item.emotionalResidueScore * 0.3),
    };
  });

  rows.sort((a, b) => b.score - a.score);

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0,
    rows: rows.slice(0, 40),
    remembered72hCount: rows.filter((row) => row.remembered72h).length,
    quotedBackCount: rows.filter((row) => row.quotedBack).length,
    delayedRevisitCount: rows.filter((row) => row.delayedRevisit).length,
    delayedReflectionCount: rows.filter((row) => row.delayedReflection).length,
    copiedReopenedCount: rows.filter((row) => row.copiedReopened).length,
  };
}

export function findDelayedRevisitGapDays(minDays = 2, maxDays = 6): number | null {
  const events = readRetentionLoopEvents().filter(
    (event) => event.kind === "entry_revisited" || event.kind === "old_entry_opened_from_note",
  );
  if (events.length < 2) return null;

  const sorted = [...events].sort(
    (a, b) => new Date(a.at).getTime() - new Date(b.at).getTime(),
  );
  for (let i = 1; i < sorted.length; i += 1) {
    const gap = daysBetweenKeys(toDayKey(sorted[i - 1].at), toDayKey(sorted[i].at));
    if (gap >= minDays && gap <= maxDays) return gap;
  }
  return null;
}
