import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { LAUNCH_EVENTS, countLocalEvents, readLocalEvents } from "@/lib/local-analytics";
import {
  readManualStudyNotes,
  getOrCreateParticipantId,
} from "@/lib/research/retention-observation";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { readLastBackupAt } from "@/lib/sync/status-storage";
import { readStoredIncidents } from "@/lib/validation/incidents";
import {
  QUIET_SHARE_EVENT,
  QUIET_SHARE_PNG_EVENT,
} from "@/lib/sharing/share-observation";
import type {
  FounderWillingnessLabel,
  WillingnessBehaviorSignal,
  WillingnessLabelRecord,
  WillingnessSignalsReport,
  WillingnessSignalKind,
} from "@/types/validation-ops";

const LABELS_KEY = "voicememory_willingness_founder_labels";
const MAX_LABELS = 80;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readLabelsRaw(): WillingnessLabelRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(LABELS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as WillingnessLabelRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeLabelsRaw(rows: WillingnessLabelRecord[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(LABELS_KEY, JSON.stringify(rows.slice(-MAX_LABELS)));
}

export function readWillingnessFounderLabels(
  participantId?: string,
): WillingnessLabelRecord[] {
  const rows = readLabelsRaw().sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  if (!participantId) return rows;
  return rows.filter((row) => row.participantId === participantId);
}

export function saveWillingnessFounderLabel(input: {
  participantId: string;
  label: FounderWillingnessLabel;
  note?: string;
}): WillingnessLabelRecord {
  const record: WillingnessLabelRecord = {
    id: crypto.randomUUID(),
    participantId: input.participantId,
    label: input.label,
    note: input.note?.trim() || undefined,
    createdAt: new Date().toISOString(),
  };
  writeLabelsRaw([...readLabelsRaw(), record]);
  return record;
}

function signal(
  kind: WillingnessSignalKind,
  label: string,
  detail: string,
  at: string,
  strength: number,
): WillingnessBehaviorSignal {
  return { id: `wtp-${kind}-${at.slice(0, 10)}`, kind, label, detail, at, strength };
}

function detectAbsenceReturn(): WillingnessBehaviorSignal | null {
  const returnDays = new Set<string>();
  for (const event of readRetentionLoopEvents()) {
    returnDays.add(toDayKey(event.at));
  }
  for (const event of readLocalEvents()) {
    returnDays.add(toDayKey(event.at));
  }

  const sorted = [...returnDays].sort();
  if (sorted.length < 2) return null;

  let maxGap = 0;
  let gapEnd = sorted[1];
  for (let i = 1; i < sorted.length; i += 1) {
    const gap = daysBetweenKeys(sorted[i - 1], sorted[i]);
    if (gap > maxGap) {
      maxGap = gap;
      gapEnd = sorted[i];
    }
  }

  if (maxGap < 5) return null;

  return signal(
    "revisited_after_absence",
    "Returned after absence",
    `${maxGap}-day gap before returning on ${gapEnd}`,
    gapEnd,
    Math.min(90, 50 + maxGap * 2),
  );
}

function detectReturnAfterFailedSync(): WillingnessBehaviorSignal | null {
  const incidents = readStoredIncidents().filter((row) => row.kind === "failed_sync" && !row.resolved);
  if (incidents.length === 0) return null;

  const lastSyncFail = incidents.sort(
    (a, b) => new Date(b.detectedAt).getTime() - new Date(a.detectedAt).getTime(),
  )[0];

  const eventsAfter = readLocalEvents().filter(
    (event) => new Date(event.at).getTime() > new Date(lastSyncFail.detectedAt).getTime(),
  );

  if (eventsAfter.length === 0) return null;

  return signal(
    "returned_after_failed_sync",
    "Returned after failed sync",
    `Activity resumed after sync failure on ${lastSyncFail.detectedAt.slice(0, 10)}`,
    eventsAfter[0].at,
    72,
  );
}

function detectWouldMissArchive(): WillingnessBehaviorSignal | null {
  const notes = readManualStudyNotes();
  const match = notes.find(
    (note) =>
      note.feltRemembered ||
      note.payReason?.toLowerCase().includes("miss") ||
      note.userQuote?.toLowerCase().includes("miss"),
  );
  if (!match) return null;

  return signal(
    "would_miss_archive",
    "Said they would miss the archive",
    match.payReason || match.userQuote || "Manual note — felt remembered",
    match.createdAt,
    85,
  );
}

/** Observe willingness-to-pay signals — behavioral only, no paywalls. */
export function buildWillingnessSignalsReport(): WillingnessSignalsReport {
  const behavioral: WillingnessBehaviorSignal[] = [];
  const events = readLocalEvents();

  if (countLocalEvents(LAUNCH_EVENTS.upgradeClicked) > 0) {
    const last = [...events].reverse().find((e) => e.name === LAUNCH_EVENTS.upgradeClicked);
    behavioral.push(
      signal(
        "asked_about_pricing",
        "Asked about pricing",
        `${countLocalEvents(LAUNCH_EVENTS.upgradeClicked)} pricing interest signal(s)`,
        last?.at ?? new Date().toISOString(),
        70,
      ),
    );
  }

  if (countLocalEvents(LAUNCH_EVENTS.exportUsed) > 0) {
    const last = [...events].reverse().find((e) => e.name === LAUNCH_EVENTS.exportUsed);
    behavioral.push(
      signal(
        "exported_archive",
        "Exported archive",
        `${countLocalEvents(LAUNCH_EVENTS.exportUsed)} export(s)`,
        last?.at ?? new Date().toISOString(),
        75,
      ),
    );
  }

  if (readLastBackupAt()) {
    behavioral.push(
      signal(
        "enabled_backup",
        "Enabled backup",
        `Last backup ${readLastBackupAt()}`,
        readLastBackupAt()!,
        68,
      ),
    );
  }

  const absence = detectAbsenceReturn();
  if (absence) behavioral.push(absence);

  const afterSync = detectReturnAfterFailedSync();
  if (afterSync) behavioral.push(afterSync);

  const copied =
    countLocalEvents(LAUNCH_EVENTS.memoryMomentCopied) +
    events.filter((e) => e.name === QUIET_SHARE_EVENT || e.name === QUIET_SHARE_PNG_EVENT).length;

  if (copied > 0) {
    const last = [...events]
      .reverse()
      .find(
        (e) =>
          e.name === LAUNCH_EVENTS.memoryMomentCopied ||
          e.name === QUIET_SHARE_EVENT ||
          e.name === QUIET_SHARE_PNG_EVENT,
      );
    behavioral.push(
      signal(
        "copied_or_shared_moment",
        "Copied or shared meaningful moments",
        `${copied} copy/share action(s)`,
        last?.at ?? new Date().toISOString(),
        62,
      ),
    );
  }

  const missArchive = detectWouldMissArchive();
  if (missArchive) behavioral.push(missArchive);

  const founderLabels = readWillingnessFounderLabels();
  const currentId = getOrCreateParticipantId();

  return {
    generatedAt: new Date().toISOString(),
    hasData: behavioral.length > 0 || founderLabels.length > 0,
    behavioral: behavioral.sort((a, b) => b.strength - a.strength),
    founderLabels,
    summary: {
      wouldPay: founderLabels.filter((row) => row.label === "would_pay").length,
      maybe: founderLabels.filter((row) => row.label === "maybe").length,
      unlikely: founderLabels.filter((row) => row.label === "unlikely").length,
      behavioralCount: behavioral.length,
    },
  };
}

export function willingnessLabelForParticipant(
  participantId: string = getOrCreateParticipantId(),
): FounderWillingnessLabel | null {
  const latest = readWillingnessFounderLabels(participantId)[0];
  return latest?.label ?? null;
}
