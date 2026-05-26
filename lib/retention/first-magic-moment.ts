import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  LAUNCH_EVENTS,
  readLocalEvents,
  trackLocalEvent,
} from "@/lib/local-analytics";
import { pickFirstMeaningfulRevisitCandidate } from "@/lib/revisit/first-meaningful-revisit";
import {
  assessRevisitQuality,
  isRevisitQualityNote,
  REVISIT_QUALITY_MEANINGFUL_MIN,
} from "@/lib/revisit/revisit-quality";
import { assessResurfacingConfidence } from "@/lib/revisit/resurfacing-confidence";
import { getAllEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
  MagicCandidateQualification,
  MagicEngagementKind,
  MagicEvidenceKind,
  MagicMomentEventName,
  MagicMomentMetrics,
} from "@/types/first-magic-moment";

export const MAGIC_MOMENT_EVENTS = {
  candidateCreated: "magic_candidate_created",
  candidateShown: "magic_candidate_shown",
  candidateOpened: "magic_candidate_opened",
  candidateSaved: "magic_candidate_saved",
  candidateShared: "magic_candidate_shared",
  followupRecorded: "magic_followup_recorded",
  returnAfterCallback: "magic_return_after_callback",
} as const satisfies Record<string, MagicMomentEventName>;

const CONFIRMED_KEY = "voicememory_first_magic_confirmed";
const CREATED_NOTES_KEY = "voicememory_magic_candidate_notes";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function eventAtMs(at: string): number {
  return new Date(at).getTime();
}

function readCreatedNoteIds(): Set<string> {
  if (!isBrowser()) return new Set();
  try {
    const raw = localStorage.getItem(CREATED_NOTES_KEY);
    if (!raw) return new Set();
    const parsed = JSON.parse(raw) as string[];
    return new Set(Array.isArray(parsed) ? parsed : []);
  } catch {
    return new Set();
  }
}

function rememberCreatedNoteId(noteId: string): void {
  if (!isBrowser()) return;
  const ids = readCreatedNoteIds();
  ids.add(noteId);
  localStorage.setItem(CREATED_NOTES_KEY, JSON.stringify([...ids].slice(-120)));
}

function gapDaysForNote(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entries.find((entry) => entry.id === note.pastEntryId);
  const current = entries.find((entry) => entry.id === note.entryId);
  if (!past || !current) return 0;
  return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
}

function referencesPriorReflection(note: MemoryNote, entries: JournalEntry[]): boolean {
  if (note.pastEntryId?.trim() || note.pastQuote?.trim()) return true;
  if (!note.entryId?.trim()) return false;

  const target = entries.find((entry) => entry.id === note.entryId);
  if (!target) return false;

  const targetMs = new Date(target.createdAt).getTime();
  const hasOlderReflection = entries.some(
    (entry) =>
      entry.id !== note.entryId &&
      new Date(entry.createdAt).getTime() < targetMs - 24 * 60 * 60 * 1000,
  );

  return hasOlderReflection && (isRevisitQualityNote(note) || note.category === "returned");
}

function collectMagicEvidence(
  note: MemoryNote,
  entries: JournalEntry[],
  qualityTotal: number,
  beforeAfterContrast: number,
  wordingPreservation: number,
): MagicEvidenceKind[] {
  const evidence: MagicEvidenceKind[] = [];
  const id = note.id.toLowerCase();

  if (
    id.includes("phrase") ||
    id.includes("knows-me-phrase") ||
    wordingPreservation >= 52
  ) {
    evidence.push("repeated_phrase");
  }

  if (
    id.includes("topic") ||
    id.includes("entity") ||
    id.includes("loop") ||
    id.includes("concern")
  ) {
    evidence.push("repeated_concern");
  }

  if (
    id.includes("calmer") ||
    id.includes("heavier") ||
    id.includes("tvn") ||
    id.includes("then-vs") ||
    id.includes("different") ||
    id.includes("revisit-") ||
    (note.pastQuote?.trim() && note.currentQuote?.trim()) ||
    beforeAfterContrast >= 55
  ) {
    evidence.push("mood_shift");
  }

  const gapDays = gapDaysForNote(note, entries);
  if (gapDays >= 7 || (note.pastDateLabel && note.currentDateLabel && gapDays >= 3)) {
    evidence.push("time_gap");
  }

  if (qualityTotal >= REVISIT_QUALITY_MEANINGFUL_MIN && note.pastQuote?.trim()) {
    evidence.push("repeated_phrase");
  }

  return [...new Set(evidence)];
}

function isSpecificEnough(
  note: MemoryNote,
  entries: JournalEntry[],
): { ok: boolean; classification: string; total: number; dimensions: ReturnType<typeof assessRevisitQuality>["dimensions"] } {
  if (note.id.startsWith("first-aha-")) {
    const candidate = pickFirstMeaningfulRevisitCandidate(entries);
    if (!candidate || candidate.payoffScore < 54) {
      return { ok: false, classification: "weak_revisit", total: 0, dimensions: assessRevisitQuality(note, entries).dimensions };
    }
    return {
      ok: true,
      classification: "meaningful_revisit",
      total: candidate.payoffScore,
      dimensions: assessRevisitQuality(note, entries).dimensions,
    };
  }

  const verdict = assessRevisitQuality(note, entries);
  const ok =
    !verdict.suppressed &&
    verdict.classification !== "weak_revisit" &&
    (verdict.classification === "meaningful_revisit" ||
      verdict.classification === "durable_revisit" ||
      verdict.protected ||
      verdict.total >= REVISIT_QUALITY_MEANINGFUL_MIN);

  return {
    ok,
    classification: verdict.classification,
    total: verdict.total,
    dimensions: verdict.dimensions,
  };
}

/** Whether a callback qualifies as a first magic moment candidate — internal only. */
export function qualifyMagicCandidate(
  note: MemoryNote,
  entries: JournalEntry[],
): MagicCandidateQualification | null {
  if (!note.id?.trim() || !note.text?.trim()) return null;
  if (!referencesPriorReflection(note, entries)) return null;

  const specificity = isSpecificEnough(note, entries);
  if (!specificity.ok) return null;

  const confidence = assessResurfacingConfidence(note, entries);
  if (confidence.suppressed || confidence.classification === "weak") {
    return null;
  }
  if (
    confidence.classification !== "magic_candidate" &&
    confidence.classification !== "strong" &&
    confidence.classification !== "plausible"
  ) {
    return null;
  }

  const evidence = collectMagicEvidence(
    note,
    entries,
    specificity.total,
    specificity.dimensions.beforeAfterContrast,
    specificity.dimensions.wordingPreservation,
  );
  if (evidence.length === 0) return null;

  return {
    noteId: note.id,
    entryId: note.entryId,
    pastEntryId: note.pastEntryId,
    evidence,
    classification: specificity.classification,
    qualityTotal: specificity.total,
  };
}

function trackMagicEvent(
  name: MagicMomentEventName,
  meta: Record<string, string>,
): void {
  trackLocalEvent(name, meta);
}

function markCandidateCreated(qualification: MagicCandidateQualification, surface?: string): void {
  const created = readCreatedNoteIds();
  if (created.has(qualification.noteId)) return;

  rememberCreatedNoteId(qualification.noteId);
  trackMagicEvent(MAGIC_MOMENT_EVENTS.candidateCreated, {
    noteId: qualification.noteId,
    entryId: qualification.entryId ?? "",
    pastEntryId: qualification.pastEntryId ?? "",
    evidence: qualification.evidence.join(","),
    classification: qualification.classification,
    qualityTotal: String(qualification.qualityTotal),
    surface: surface ?? "",
  });
  void import("@/lib/retention/first-week-funnel").then((mod) => {
    mod.observeFunnelFirstResurfacingCandidate({
      noteId: qualification.noteId,
      surface: surface ?? "",
    });
  });
}

export function wasMagicCandidate(noteId: string): boolean {
  if (readCreatedNoteIds().has(noteId)) return true;
  return readLocalEvents().some(
    (event) =>
      (event.name === MAGIC_MOMENT_EVENTS.candidateCreated ||
        event.name === MAGIC_MOMENT_EVENTS.candidateShown) &&
      event.meta?.noteId === noteId,
  );
}

function readFirstMagicConfirmed(): {
  noteId: string;
  engagement: MagicEngagementKind;
  at: string;
} | null {
  if (!isBrowser()) return null;
  try {
    const raw = localStorage.getItem(CONFIRMED_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as { noteId: string; engagement: MagicEngagementKind; at: string };
  } catch {
    return null;
  }
}

function confirmFirstMagicMoment(noteId: string, engagement: MagicEngagementKind): void {
  if (!isBrowser()) return;
  if (readFirstMagicConfirmed()) return;
  if (!wasMagicCandidate(noteId)) return;

  localStorage.setItem(
    CONFIRMED_KEY,
    JSON.stringify({
      noteId,
      engagement,
      at: new Date().toISOString(),
    }),
  );
  void import("@/lib/retention/first-week-funnel").then((mod) => {
    mod.observeFunnelFirstMagicMoment({ noteId, engagement });
  });
}

function firstReflectionAtMs(entries: JournalEntry[] = getAllEntries()): number | null {
  const reflectionEvent = readLocalEvents().find(
    (event) => event.name === LAUNCH_EVENTS.firstReflectionCreated,
  );
  if (reflectionEvent) return eventAtMs(reflectionEvent.at);

  if (entries.length === 0) return null;
  const earliest = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  )[0];
  return new Date(earliest.createdAt).getTime();
}

/** Observe a surfaced callback — create + show magic candidate events when qualified. */
export function observeMagicCallbackSurfaced(
  note: MemoryNote,
  entries: JournalEntry[],
  surface: string,
): MagicCandidateQualification | null {
  const qualification = qualifyMagicCandidate(note, entries);
  if (!qualification) return null;

  markCandidateCreated({ ...qualification, surface }, surface);
  trackMagicEvent(MAGIC_MOMENT_EVENTS.candidateShown, {
    noteId: qualification.noteId,
    entryId: qualification.entryId ?? "",
    pastEntryId: qualification.pastEntryId ?? "",
    evidence: qualification.evidence.join(","),
    classification: qualification.classification,
    qualityTotal: String(qualification.qualityTotal),
    surface,
  });

  return qualification;
}

export function observeMagicCandidateOpened(
  noteId: string,
  meta?: { entryId?: string; source?: string },
): void {
  if (!wasMagicCandidate(noteId)) return;

  trackMagicEvent(MAGIC_MOMENT_EVENTS.candidateOpened, {
    noteId,
    entryId: meta?.entryId ?? "",
    source: meta?.source ?? "",
  });
  confirmFirstMagicMoment(noteId, "opened");
}

export function observeMagicCandidateSaved(noteId: string, entryId?: string): void {
  if (!noteId || !wasMagicCandidate(noteId)) return;

  trackMagicEvent(MAGIC_MOMENT_EVENTS.candidateSaved, {
    noteId,
    entryId: entryId ?? "",
  });
  confirmFirstMagicMoment(noteId, "saved");
}

export function observeMagicCandidateShared(noteId: string, sourceId?: string): void {
  if (!noteId || !wasMagicCandidate(noteId)) return;

  trackMagicEvent(MAGIC_MOMENT_EVENTS.candidateShared, {
    noteId,
    sourceId: sourceId ?? "",
  });
  confirmFirstMagicMoment(noteId, "shared");
}

export function observeMagicFollowupRecorded(noteId: string, entryId?: string): void {
  if (!noteId || !wasMagicCandidate(noteId)) return;

  trackMagicEvent(MAGIC_MOMENT_EVENTS.followupRecorded, {
    noteId,
    entryId: entryId ?? "",
  });
  confirmFirstMagicMoment(noteId, "followup_recorded");
}

export function observeMagicReturnAfterCallback(noteId: string, entryId?: string): void {
  if (!noteId || !wasMagicCandidate(noteId)) return;

  trackMagicEvent(MAGIC_MOMENT_EVENTS.returnAfterCallback, {
    noteId,
    entryId: entryId ?? "",
  });
  confirmFirstMagicMoment(noteId, "return_after_callback");
}

export function computeMagicMomentMetrics(
  entries: JournalEntry[] = getAllEntries(),
): MagicMomentMetrics {
  const magicNames = new Set<string>(Object.values(MAGIC_MOMENT_EVENTS));
  const events = readLocalEvents().filter((event) => magicNames.has(event.name));

  const shownNoteIds = new Set<string>();
  const openedNoteIds = new Set<string>();

  for (const event of events) {
    const noteId = event.meta?.noteId;
    if (!noteId) continue;
    if (event.name === MAGIC_MOMENT_EVENTS.candidateShown) shownNoteIds.add(noteId);
    if (event.name === MAGIC_MOMENT_EVENTS.candidateOpened) openedNoteIds.add(noteId);
  }

  const openedAmongShown = [...openedNoteIds].filter((id) => shownNoteIds.has(id)).length;
  const callbackOpenRate =
    shownNoteIds.size === 0 ? 0 : Math.round((openedAmongShown / shownNoteIds.size) * 100);

  const firstShown = events.find((event) => event.name === MAGIC_MOMENT_EVENTS.candidateShown);
  const reflectionAt = firstReflectionAtMs(entries);
  const timeUntilFirstMeaningfulCallbackMs =
    reflectionAt !== null && firstShown
      ? Math.max(0, eventAtMs(firstShown.at) - reflectionAt)
      : null;

  const confirmed = readFirstMagicConfirmed();

  return {
    timeUntilFirstMeaningfulCallbackMs,
    callbackOpenRate,
    candidatesCreated: events.filter((event) => event.name === MAGIC_MOMENT_EVENTS.candidateCreated)
      .length,
    candidatesShown: events.filter((event) => event.name === MAGIC_MOMENT_EVENTS.candidateShown)
      .length,
    candidatesOpened: events.filter((event) => event.name === MAGIC_MOMENT_EVENTS.candidateOpened)
      .length,
    firstMagicConfirmedAt: confirmed?.at ?? null,
    firstMagicEngagement: confirmed?.engagement ?? null,
  };
}

export function listMagicMomentEvents(limit = 40) {
  const magicNames = new Set<string>(Object.values(MAGIC_MOMENT_EVENTS));
  return readLocalEvents()
    .filter((event) => magicNames.has(event.name))
    .slice(-limit)
    .reverse()
    .map((event) => ({
      name: event.name as MagicMomentEventName,
      at: event.at,
      noteId: event.meta?.noteId,
      surface: event.meta?.surface,
      evidence: event.meta?.evidence,
      engagement: event.meta?.engagement,
    }));
}
