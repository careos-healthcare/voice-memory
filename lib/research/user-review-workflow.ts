import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { sortByEmotionalSurvival } from "@/lib/debug/callback-quality-score";
import { buildEmotionalLegitimacyReport } from "@/lib/debug/emotional-legitimacy-review";
import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import {
  buildWillingnessSignalsReport,
  readWillingnessFounderLabels,
} from "@/lib/research/willingness-signals";
import {
  readManualStudyNotes,
  readStudyParticipantRoster,
} from "@/lib/research/retention-observation";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildRememberedLaterReport } from "@/lib/social-proof/remembered-later";
import { readStoredIncidents } from "@/lib/validation/incidents";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FounderReviewRankedItem } from "@/types/validation-phase";
import type {
  AnonymizedUserReviewExport,
  FounderFollowUpReminder,
  FounderUserNote,
  UserReviewReport,
  UserReviewSection,
} from "@/types/validation-ops";

const NOTES_KEY = "voicememory_founder_user_notes";
const REMINDERS_KEY = "voicememory_founder_followup_reminders";
const MAX_NOTES = 120;
const MAX_REMINDERS = 60;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function ranked(id: string, label: string, detail?: string, score?: number): FounderReviewRankedItem {
  return { id, label, detail, score };
}

function section(title: string, rows: FounderReviewRankedItem[], empty: string): UserReviewSection {
  return { title, rows, empty };
}

function readNotesRaw(): FounderUserNote[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(NOTES_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as FounderUserNote[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeNotesRaw(rows: FounderUserNote[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(NOTES_KEY, JSON.stringify(rows.slice(-MAX_NOTES)));
}

function readRemindersRaw(): FounderFollowUpReminder[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(REMINDERS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as FounderFollowUpReminder[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRemindersRaw(rows: FounderFollowUpReminder[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(REMINDERS_KEY, JSON.stringify(rows.slice(-MAX_REMINDERS)));
}

export function readFounderUserNotes(participantId: string): FounderUserNote[] {
  return readNotesRaw()
    .filter((row) => row.participantId === participantId)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}

export function saveFounderUserNote(participantId: string, text: string): FounderUserNote {
  const note: FounderUserNote = {
    id: crypto.randomUUID(),
    participantId,
    text: text.trim(),
    createdAt: new Date().toISOString(),
  };
  if (!note.text) throw new Error("Note cannot be empty.");
  writeNotesRaw([...readNotesRaw(), note]);
  return note;
}

export function readFollowUpReminders(participantId?: string): FounderFollowUpReminder[] {
  const rows = readRemindersRaw().sort((a, b) => a.dueDay.localeCompare(b.dueDay));
  if (!participantId) return rows;
  return rows.filter((row) => row.participantId === participantId);
}

export function saveFollowUpReminder(input: {
  participantId: string;
  dueDay: string;
  note: string;
}): FounderFollowUpReminder {
  const reminder: FounderFollowUpReminder = {
    id: crypto.randomUUID(),
    participantId: input.participantId,
    dueDay: input.dueDay,
    note: input.note.trim(),
    completed: false,
    createdAt: new Date().toISOString(),
  };
  if (!reminder.note) throw new Error("Reminder note cannot be empty.");
  writeRemindersRaw([...readRemindersRaw(), reminder]);
  return reminder;
}

export function completeFollowUpReminder(reminderId: string): void {
  writeRemindersRaw(
    readRemindersRaw().map((row) =>
      row.id === reminderId ? { ...row, completed: true } : row,
    ),
  );
}

/** Per-tester founder review — debug only. */
export function buildUserReviewReport(participantId: string): UserReviewReport {
  const roster = readStudyParticipantRoster();
  const participant =
    roster.find((row) => row.id === participantId) ??
    roster[0] ?? {
      id: participantId,
      label: "Unknown",
      anchorDay: new Date().toISOString().slice(0, 10),
      addedAt: new Date().toISOString(),
      active: true,
    };

  const entries = getMemoryEligibleEntries();
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const loops = buildRetentionLoopReport();
  const legitimacy = buildEmotionalLegitimacyReport(entries);
  const attachment = buildArchiveAttachmentReport(entries);
  const willingness = buildWillingnessSignalsReport();
  const remembered = buildRememberedLaterReport(entries);
  const manualNotes = readManualStudyNotes().filter(
    (note) => !note.participantId || note.participantId === participantId,
  );
  const incidents = readStoredIncidents();

  const strongestCallbacks = sortByEmotionalSurvival(callbackReport.items)
    .filter((item) => item.survival.emotionalSurvivalScore >= 40)
    .slice(0, 8)
    .map((item) =>
      ranked(
        item.id,
        item.text.slice(0, 120),
        `survival ${item.survival.emotionalSurvivalScore}`,
        item.survival.emotionalSurvivalScore,
      ),
    );

  const ignoredCallbacks = callbackReport.items
    .filter(
      (item) =>
        item.survival.callbackShownCount >= 2 &&
        item.survival.emotionalSurvivalScore < 25 &&
        item.survival.oldEntryRevisitCount === 0,
    )
    .slice(0, 8)
    .map((item) =>
      ranked(item.id, item.text.slice(0, 120), `shown ${item.survival.callbackShownCount} · ignored`),
    );

  const revisitBehavior = [
    ...loops.notesCausingRevisits.slice(0, 5).map((row) =>
      ranked(row.noteId, row.noteText.slice(0, 100), `${row.clicks} clicks · ${row.oldEntryOpens} opens`),
    ),
    ...loops.revisitsCausingReflections.slice(0, 4).map((row) =>
      ranked(row.entryId, `Revisit → reflection`, row.sources),
    ),
  ];

  const reflectionContinuation = [
    ranked(
      "followups",
      "Follow-up continuation",
      `${loops.events.filter((e) => e.kind === "followup_recording_started").length} started · ${loops.events.filter((e) => e.kind === "followup_recording_completed").length} completed`,
    ),
    ...loops.revisitsCausingReflections
      .filter((row) => row.reflectionEntryId)
      .slice(0, 4)
      .map((row) => ranked(row.reflectionEntryId!, "New reflection after revisit", row.revisitedAt.slice(0, 10))),
  ];

  const trustIncidents = incidents
    .filter((row) => !row.resolved)
    .slice(0, 6)
    .map((row, index) => ranked(`incident-${index}`, row.kind, row.detail.slice(0, 120)));

  const emotionalLegitimacy = [
    ranked("overall", "Overall legitimacy", undefined, legitimacy.scores.overall),
    ranked("residue", "Emotional residue", undefined, legitimacy.scores.emotionalResidue),
    ranked("revisit-auth", "Revisit authenticity", undefined, legitimacy.scores.revisitAuthenticity),
    ranked("overclaim", "Overclaim risk", undefined, legitimacy.scores.overclaimRisk),
  ];

  const attachmentSignals = attachment.signals.slice(0, 6).map((row) =>
    ranked(row.id, row.label, row.detail, row.strength),
  );

  const willingnessSignals = [
    ...willingness.behavioral.slice(0, 4).map((row) =>
      ranked(row.id, row.label, row.detail, row.strength),
    ),
    ...readWillingnessFounderLabels(participantId).slice(0, 2).map((row) =>
      ranked(row.id, `Founder label: ${row.label}`, row.note),
    ),
  ];

  const feltRemembered = manualNotes
    .filter((note) => note.feltRemembered)
    .slice(0, 6)
    .map((note) =>
      ranked(note.id, note.userQuote || note.rememberedSentence48h || "Felt remembered", note.createdAt.slice(0, 10)),
    );

  const feltGeneric = manualNotes
    .filter((note) => note.feltGeneric)
    .slice(0, 6)
    .map((note) =>
      ranked(note.id, note.userQuote || note.rememberedSentence48h || "Felt generic", note.createdAt.slice(0, 10)),
    );

  if (feltRemembered.length === 0 && remembered.rows.length > 0) {
    for (const row of remembered.rows.slice(0, 3)) {
      feltRemembered.push(
        ranked(row.callbackId, row.text.slice(0, 100), `${row.kind} · score ${row.score}`),
      );
    }
  }

  return {
    generatedAt: new Date().toISOString(),
    participant,
    sections: {
      strongestCallbacks: section("Strongest callbacks", strongestCallbacks, "No strong callbacks yet."),
      ignoredCallbacks: section("Ignored callbacks", ignoredCallbacks, "No ignored callbacks flagged."),
      revisitBehavior: section("Revisit behavior", revisitBehavior, "No revisit behavior yet."),
      reflectionContinuation: section("Reflection continuation", reflectionContinuation, "No continuation yet."),
      trustIncidents: section("Trust incidents", trustIncidents, "No open trust incidents."),
      emotionalLegitimacy: section("Emotional legitimacy", emotionalLegitimacy, "Not enough data."),
      attachmentSignals: section("Attachment signals", attachmentSignals, "No attachment signals yet."),
      willingnessSignals: section("Willingness signals", willingnessSignals, "No willingness signals yet."),
      feltRemembered: section("Felt remembered", feltRemembered, "No felt remembered reports."),
      feltGeneric: section("Felt generic", feltGeneric, "No felt generic reports."),
    },
    founderNotes: readFounderUserNotes(participantId),
    followUpReminders: readFollowUpReminders(participantId),
  };
}

export function buildAnonymizedUserReviewExport(
  participantId: string,
): AnonymizedUserReviewExport {
  const report = buildUserReviewReport(participantId);
  const willingness = buildWillingnessSignalsReport();
  const attachment = buildArchiveAttachmentReport();

  return {
    schemaVersion: 1,
    exportedAt: new Date().toISOString(),
    participantLabel: report.participant.label ?? "anonymous",
    studyDayCount: Math.max(0, report.participant.anchorDay ? 1 : 0),
    sections: report.sections,
    willingnessSummary: willingness.summary,
    attachmentScore: attachment.attachmentScore,
    rolloutStage: "prototype",
  };
}

export function downloadUserReviewJson(participantId: string): void {
  if (!isBrowser()) return;

  const payload = buildAnonymizedUserReviewExport(participantId);
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `user-review-${participantId.slice(0, 8)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}
