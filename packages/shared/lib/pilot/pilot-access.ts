import {
  getOrCreateParticipantId,
  readStudyParticipantRoster,
} from "@/lib/research/retention-observation";
import type {
  PilotAccessRecord,
  PilotAccessReport,
  PilotAccessStatus,
  PilotFounderNote,
} from "@/types/pilot-system";

const ACCESS_KEY = "voicememory_pilot_access";
const NOTES_KEY = "voicememory_pilot_founder_notes";
export const PILOT_MAX_USERS = 20;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readAccessRaw(): PilotAccessRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(ACCESS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as PilotAccessRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAccessRaw(rows: PilotAccessRecord[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(ACCESS_KEY, JSON.stringify(rows.slice(0, PILOT_MAX_USERS)));
}

function readNotesRaw(): PilotFounderNote[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(NOTES_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as PilotFounderNote[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeNotesRaw(rows: PilotFounderNote[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(NOTES_KEY, JSON.stringify(rows.slice(-PILOT_MAX_USERS)));
}

export function readPilotAccessRecord(participantId: string): PilotAccessRecord | null {
  return readAccessRaw().find((row) => row.participantId === participantId) ?? null;
}

export function setPilotAccessStatus(input: {
  participantId: string;
  status: PilotAccessStatus;
  label?: string;
}): PilotAccessRecord {
  const roster = readStudyParticipantRoster();
  const existing = readAccessRaw();
  const match = roster.find((row) => row.id === input.participantId);
  const prior = existing.find((row) => row.participantId === input.participantId);
  const notes = readNotesRaw().find((row) => row.participantId === input.participantId) ?? null;

  const record: PilotAccessRecord = {
    participantId: input.participantId,
    label: input.label ?? match?.label ?? prior?.label,
    status: input.status,
    founderNotes: notes,
    updatedAt: new Date().toISOString(),
  };

  const next = [...existing.filter((row) => row.participantId !== input.participantId), record];
  writeAccessRaw(next);
  return record;
}

export function savePilotFounderNote(input: {
  participantId: string;
  attachmentStrength?: string;
  trustSensitivity?: string;
  archiveMaturity?: string;
  continuityUsage?: string;
  revisitDepth?: string;
  text?: string;
}): PilotFounderNote {
  const note: PilotFounderNote = {
    id: crypto.randomUUID(),
    participantId: input.participantId,
    attachmentStrength: input.attachmentStrength?.trim() || undefined,
    trustSensitivity: input.trustSensitivity?.trim() || undefined,
    archiveMaturity: input.archiveMaturity?.trim() || undefined,
    continuityUsage: input.continuityUsage?.trim() || undefined,
    revisitDepth: input.revisitDepth?.trim() || undefined,
    text: input.text?.trim() || undefined,
    updatedAt: new Date().toISOString(),
  };

  const notes = readNotesRaw().filter((row) => row.participantId !== input.participantId);
  writeNotesRaw([...notes, note]);

  const access = readPilotAccessRecord(input.participantId);
  if (access) {
    setPilotAccessStatus({
      participantId: input.participantId,
      status: access.status,
      label: access.label,
    });
  } else {
    setPilotAccessStatus({
      participantId: input.participantId,
      status: "observing",
      label: readStudyParticipantRoster().find((r) => r.id === input.participantId)?.label,
    });
  }

  return note;
}

export function ensureCurrentParticipantObserving(): PilotAccessRecord {
  const participantId = getOrCreateParticipantId();
  const existing = readPilotAccessRecord(participantId);
  if (existing) return existing;

  return setPilotAccessStatus({
    participantId,
    status: "observing",
    label: readStudyParticipantRoster().find((r) => r.id === participantId)?.label ?? "This device",
  });
}

export function buildPilotAccessReport(): PilotAccessReport {
  const notes = readNotesRaw();
  const roster = readAccessRaw().map((row) => ({
    ...row,
    founderNotes: notes.find((note) => note.participantId === row.participantId) ?? row.founderNotes,
  }));
  const approved = roster.filter((row) => row.status === "approved").length;
  const invited = roster.filter((row) => row.status === "invited").length;
  const observing = roster.filter((row) => row.status === "observing").length;
  const declined = roster.filter((row) => row.status === "declined").length;

  return {
    generatedAt: new Date().toISOString(),
    roster: roster.sort(
      (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
    ),
    approvedCount: approved,
    invitedCount: invited,
    observingCount: observing,
    declinedCount: declined,
    capacityRemaining: Math.max(0, PILOT_MAX_USERS - approved - invited),
  };
}

export function isPilotApproved(participantId: string = getOrCreateParticipantId()): boolean {
  const record = readPilotAccessRecord(participantId);
  return record?.status === "approved" || record?.status === "invited";
}
