import { buildArchiveOwnershipReport } from "@/lib/archive/archive-ownership";
import { addDaysToKey, daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { LAUNCH_EVENTS, countLocalEvents, readLocalEvents } from "@/lib/local-analytics";
import {
  buildRetentionLoopReport,
  readRetentionLoopEvents,
  type RetentionLoopEvent,
} from "@/lib/retention/retention-loops";
import { readLastBackupAt } from "@/lib/sync/status-storage";
import { getAllEntries } from "@/lib/storage";
import type {
  AnonymizedStudyExport,
  ArchiveProtectionBehavior,
  ManualStudyNote,
  ParticipantSnapshot,
  RetentionObservationSnapshot,
  RetentionWindowIndicator,
  RevisitFunnelStep,
  StudyParticipantRecord,
  StudyParticipantStatus,
  WouldPayAnswer,
} from "@/types/retention-observation";

const MANUAL_NOTES_KEY = "voicememory_retention_study_manual";
const PARTICIPANT_KEY = "voicememory_study_participant_id";
const PARTICIPANT_ROSTER_KEY = "voicememory_study_participant_roster";
const ANCHOR_KEY = "voicememory_study_anchor_day";
const MAX_MANUAL_NOTES = 120;
const MAX_PARTICIPANTS = 20;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function sortedEntries() {
  return [...getAllEntries()].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

export function getOrCreateParticipantId(): string {
  if (!isBrowser()) return "server";
  const existing = localStorage.getItem(PARTICIPANT_KEY);
  if (existing) return existing;
  const id = `p-${crypto.randomUUID().replace(/-/g, "").slice(0, 10)}`;
  localStorage.setItem(PARTICIPANT_KEY, id);
  return id;
}

export function getStudyAnchorDay(): string {
  if (!isBrowser()) return todayKey();

  const stored = localStorage.getItem(ANCHOR_KEY);
  if (stored) return stored;

  const entries = sortedEntries();
  const anchor = entries.length > 0 ? toDayKey(entries[0].createdAt) : todayKey();
  localStorage.setItem(ANCHOR_KEY, anchor);
  return anchor;
}

export function resetStudyAnchorDay(dayKey?: string): string {
  if (!isBrowser()) return todayKey();
  const anchor = dayKey ?? todayKey();
  localStorage.setItem(ANCHOR_KEY, anchor);
  return anchor;
}

function readParticipantRosterRaw(): StudyParticipantRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(PARTICIPANT_ROSTER_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as StudyParticipantRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeParticipantRosterRaw(roster: StudyParticipantRecord[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(PARTICIPANT_ROSTER_KEY, JSON.stringify(roster.slice(0, MAX_PARTICIPANTS)));
}

function ensureCurrentParticipantInRoster(): StudyParticipantRecord[] {
  const currentId = getOrCreateParticipantId();
  const anchor = getStudyAnchorDay();
  const roster = readParticipantRosterRaw();
  if (!roster.some((row) => row.id === currentId)) {
    roster.unshift({
      id: currentId,
      label: "This device",
      anchorDay: anchor,
      addedAt: new Date().toISOString(),
      active: true,
    });
    writeParticipantRosterRaw(roster);
  }
  return readParticipantRosterRaw();
}

export function readStudyParticipantRoster(): StudyParticipantRecord[] {
  return ensureCurrentParticipantInRoster();
}

export function addStudyParticipant(label?: string): StudyParticipantRecord {
  if (!isBrowser()) {
    return {
      id: "server",
      label,
      anchorDay: todayKey(),
      addedAt: new Date().toISOString(),
      active: true,
    };
  }

  const roster = ensureCurrentParticipantInRoster();
  if (roster.length >= MAX_PARTICIPANTS) {
    throw new Error(`Participant roster full (${MAX_PARTICIPANTS}).`);
  }

  const id = `p-${crypto.randomUUID().replace(/-/g, "").slice(0, 10)}`;
  const record: StudyParticipantRecord = {
    id,
    label: label?.trim() || `Participant ${roster.length + 1}`,
    anchorDay: todayKey(),
    addedAt: new Date().toISOString(),
    active: true,
  };
  writeParticipantRosterRaw([record, ...roster]);
  return record;
}

export function removeStudyParticipant(participantId: string): void {
  const roster = readParticipantRosterRaw().filter((row) => row.id !== participantId);
  writeParticipantRosterRaw(roster);
}

export function setActiveStudyParticipant(participantId: string): void {
  if (!isBrowser()) return;
  localStorage.setItem(PARTICIPANT_KEY, participantId);
  const roster = readParticipantRosterRaw();
  const match = roster.find((row) => row.id === participantId);
  if (match) {
    localStorage.setItem(ANCHOR_KEY, match.anchorDay);
  }
}

function buildParticipantStatuses(notes: ManualStudyNote[]): StudyParticipantStatus[] {
  const roster = ensureCurrentParticipantInRoster();
  const loopReport = buildRetentionLoopReport();
  const revisitReflection = loopReport.revisitsCausingReflections.filter(
    (row) => row.reflectionEntryId,
  ).length;

  return roster.map((participant) => {
    const participantNotes = notes.filter((note) => note.participantId === participant.id);
    const studyDayCount = Math.max(
      0,
      daysBetweenKeys(participant.anchorDay, todayKey()) + 1,
    );

    return {
      participant,
      studyDayCount,
      day7Eligible: studyDayCount >= 7,
      day30Eligible: studyDayCount >= 30,
      day60Eligible: studyDayCount >= 60,
      noteCount: participantNotes.length,
      revisitToReflection: participant.id === getOrCreateParticipantId() ? revisitReflection : 0,
      wouldPayYes: participantNotes.filter((note) => note.wouldPay === "yes").length,
      wouldPayMaybe: participantNotes.filter((note) => note.wouldPay === "maybe").length,
      feltRememberedCount: participantNotes.filter((note) => note.feltRemembered).length,
      feltGenericCount: participantNotes.filter((note) => note.feltGeneric).length,
    };
  });
}

function readManualNotesRaw(): ManualStudyNote[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(MANUAL_NOTES_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ManualStudyNote[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeManualNotesRaw(notes: ManualStudyNote[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(MANUAL_NOTES_KEY, JSON.stringify(notes.slice(-MAX_MANUAL_NOTES)));
}

export function readManualStudyNotes(): ManualStudyNote[] {
  return readManualNotesRaw().sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
}

export function saveManualStudyNote(input: {
  rememberedSentence48h?: string;
  feltRemembered?: boolean;
  feltGeneric?: boolean;
  userQuote?: string;
  wouldPay?: WouldPayAnswer;
  payReason?: string;
}): ManualStudyNote {
  const note: ManualStudyNote = {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    participantId: getOrCreateParticipantId(),
    rememberedSentence48h: input.rememberedSentence48h?.trim() || undefined,
    feltRemembered: input.feltRemembered,
    feltGeneric: input.feltGeneric,
    userQuote: input.userQuote?.trim() || undefined,
    wouldPay: input.wouldPay,
    payReason: input.payReason?.trim() || undefined,
  };

  const hasContent =
    note.rememberedSentence48h ||
    note.userQuote ||
    note.payReason ||
    note.wouldPay ||
    note.feltRemembered !== undefined ||
    note.feltGeneric !== undefined;

  if (!hasContent) {
    throw new Error("Add at least one observation field.");
  }

  writeManualNotesRaw([...readManualNotesRaw(), note]);
  return note;
}

export function clearManualStudyNotes(): number {
  const count = readManualNotesRaw().length;
  if (!isBrowser()) return 0;
  localStorage.removeItem(MANUAL_NOTES_KEY);
  return count;
}

function collectReturnDayKeys(): string[] {
  const keys = new Set<string>();

  for (const entry of sortedEntries()) {
    keys.add(toDayKey(entry.createdAt));
  }

  for (const event of readRetentionLoopEvents()) {
    keys.add(toDayKey(event.at));
  }

  for (const event of readLocalEvents()) {
    keys.add(toDayKey(event.at));
  }

  return [...keys].sort();
}

function eventsSinceDay(events: RetentionLoopEvent[], sinceDay: string): RetentionLoopEvent[] {
  return events.filter((event) => toDayKey(event.at) >= sinceDay);
}

function returnDaysInWindow(returnDayKeys: string[], anchorDay: string, windowDays: number): number {
  const endDay = addDaysToKey(anchorDay, windowDays - 1);
  return returnDayKeys.filter((day) => day >= anchorDay && day <= endDay).length;
}

function returnedAfterFirstUse(
  returnDayKeys: string[],
  anchorDay: string,
  windowDays: number,
): boolean {
  const later = returnDayKeys.filter(
    (day) => day > anchorDay && day <= addDaysToKey(anchorDay, windowDays),
  );
  return later.length > 0;
}

function buildRetentionWindow(
  windowDays: 7 | 30 | 60,
  anchorDay: string,
  studyDayCount: number,
  returnDayKeys: string[],
  events: RetentionLoopEvent[],
): RetentionWindowIndicator {
  const eligible = studyDayCount >= windowDays;
  const windowStart = anchorDay;
  const windowEvents = eventsSinceDay(events, windowStart).filter(
    (event) => daysBetweenKeys(windowStart, toDayKey(event.at)) < windowDays,
  );

  return {
    windowDays,
    eligible,
    activeReturnDays: returnDaysInWindow(returnDayKeys, anchorDay, windowDays),
    returnedAfterFirstUse: returnedAfterFirstUse(returnDayKeys, anchorDay, windowDays),
    oldEntryRevisits: windowEvents.filter((row) => row.kind === "entry_revisited").length,
    revisitToReflection: windowEvents.filter(
      (row) => row.kind === "followup_recording_completed",
    ).length,
    followupsStarted: windowEvents.filter((row) => row.kind === "followup_recording_started").length,
    followupsCompleted: windowEvents.filter((row) => row.kind === "followup_recording_completed")
      .length,
    bookmarks: windowEvents.filter((row) => row.kind === "bookmark_created").length,
    copiedMoments: windowEvents.filter((row) => row.kind === "copied_memory_moment").length,
  };
}

function buildRevisitFunnel(events: RetentionLoopEvent[]): RevisitFunnelStep[] {
  const memoryClicks = events.filter((row) => row.kind === "resurfaced_memory_clicked").length;
  const oldEntryOpens = events.filter((row) => row.kind === "old_entry_opened_from_note").length;
  const revisits = events.filter((row) => row.kind === "entry_revisited").length;
  const followupStarted = events.filter((row) => row.kind === "followup_recording_started").length;
  const followupCompleted = events.filter(
    (row) => row.kind === "followup_recording_completed",
  ).length;
  const loopReport = buildRetentionLoopReport();
  const revisitToReflection = loopReport.revisitsCausingReflections.filter(
    (row) => row.reflectionEntryId,
  ).length;

  return [
    { step: "Memory note clicked", count: memoryClicks },
    { step: "Old entry opened from note", count: oldEntryOpens },
    { step: "Old entry revisited", count: revisits },
    { step: "Follow-up started", count: followupStarted },
    { step: "Follow-up completed", count: followupCompleted },
    { step: "Revisit → new reflection", count: revisitToReflection },
  ];
}

async function buildArchiveProtectionBehavior(): Promise<ArchiveProtectionBehavior> {
  const ownership = await buildArchiveOwnershipReport();
  const exportCount = countLocalEvents(LAUNCH_EVENTS.exportUsed);

  return {
    exportUsed: exportCount > 0,
    encryptedBackupConfigured: Boolean(readLastBackupAt()) || ownership.encryptedBackupConfigured,
    localExportUsed: ownership.localExportUsed,
    backupConfigured: ownership.backupConfigured,
    exportCount,
  };
}

function buildParticipantSnapshot(
  returnDayKeys: string[],
  anchorDay: string,
): ParticipantSnapshot {
  const entries = sortedEntries();
  const oldest = entries[0];
  const newest = entries[entries.length - 1];

  return {
    participantId: getOrCreateParticipantId(),
    studyAnchorDay: anchorDay,
    studyDayCount: Math.max(0, daysBetweenKeys(anchorDay, todayKey()) + 1),
    returnDayCount: returnDayKeys.length,
    reflectionCount: entries.length,
    archiveSpanDays:
      oldest && newest
        ? daysBetweenKeys(toDayKey(oldest.createdAt), toDayKey(newest.createdAt))
        : null,
  };
}

/** Build local-only retention study snapshot for debug observation. */
export async function buildRetentionObservationSnapshot(): Promise<RetentionObservationSnapshot> {
  const anchorDay = getStudyAnchorDay();
  const returnDayKeys = collectReturnDayKeys();
  const events = readRetentionLoopEvents();
  const loopReport = buildRetentionLoopReport();
  const participant = buildParticipantSnapshot(returnDayKeys, anchorDay);
  const archiveProtection = await buildArchiveProtectionBehavior();
  const manualNotes = readManualStudyNotes();

  return {
    generatedAt: new Date().toISOString(),
    participant,
    participantRoster: buildParticipantStatuses(manualNotes),
    returnDayKeys,
    retentionWindows: ([7, 30, 60] as const).map((windowDays) =>
      buildRetentionWindow(
        windowDays,
        anchorDay,
        participant.studyDayCount,
        returnDayKeys,
        events,
      ),
    ),
    revisitFunnel: buildRevisitFunnel(events),
    archiveProtection,
    emotionalResidue: readManualStudyNotes(),
    automated: {
      oldEntryRevisits: events.filter((row) => row.kind === "entry_revisited").length,
      memoryNoteToOldEntryOpens: events.filter((row) => row.kind === "old_entry_opened_from_note")
        .length,
      revisitToReflectionLinks: loopReport.revisitsCausingReflections.filter(
        (row) => row.reflectionEntryId,
      ).length,
      followupsStarted: events.filter((row) => row.kind === "followup_recording_started").length,
      followupsCompleted: events.filter((row) => row.kind === "followup_recording_completed")
        .length,
      bookmarks: events.filter((row) => row.kind === "bookmark_created").length,
      copiedMoments: events.filter((row) => row.kind === "copied_memory_moment").length,
      day1Returns: loopReport.returnIndicators.day1Count,
      day7Returns: loopReport.returnIndicators.day7Count,
    },
  };
}

function sanitizeManualNote(note: ManualStudyNote): ManualStudyNote {
  return {
    id: note.id,
    createdAt: note.createdAt,
    rememberedSentence48h: note.rememberedSentence48h?.slice(0, 280),
    feltRemembered: note.feltRemembered,
    feltGeneric: note.feltGeneric,
    userQuote: note.userQuote?.slice(0, 280),
    wouldPay: note.wouldPay,
    payReason: note.payReason?.slice(0, 400),
  };
}

/** Anonymized export — opaque participant id, no entry ids or emails. */
export async function buildAnonymizedStudyExport(): Promise<AnonymizedStudyExport> {
  const observation = await buildRetentionObservationSnapshot();

  return {
    schemaVersion: 1,
    exportedAt: new Date().toISOString(),
    participantId: observation.participant.participantId,
    participantRoster: observation.participantRoster,
    observation: {
      ...observation,
      emotionalResidue: observation.emotionalResidue.map(sanitizeManualNote),
    },
  };
}

export function downloadStudyExportJson(exportPayload: AnonymizedStudyExport): void {
  if (!isBrowser()) return;

  const blob = new Blob([JSON.stringify(exportPayload, null, 2)], {
    type: "application/json",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `voicememory-study-${exportPayload.participantId}-${toDayKey(exportPayload.exportedAt)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}
