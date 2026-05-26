import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import {
  ADVICE_RESURFACING_RE,
  isBlockedResurfacingCopy,
  isGenericResurfacingCopy,
  isMoodOrThemeOnlyResurface,
  OVERCLAIM_RESURFACING_RE,
  pickResurfacingHeadline,
  RESURFACING_COPY,
  type ResurfacingCopyInput,
} from "@/lib/revisit/resurfacing-copy";
import {
  assessResurfacingConfidence,
  collectResurfacingConfidenceCandidates,
} from "@/lib/revisit/resurfacing-confidence";
import { assessResurfacingTiming } from "@/lib/revisit/resurfacing-timing";
import {
  assessResurfacingWhyNow,
  hasResurfacingWhyNow,
} from "@/lib/revisit/resurfacing-why-now";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { ResurfacingConfidenceVerdict } from "@/types/resurfacing-confidence";
import type { ResurfacingTimingVerdict } from "@/types/resurfacing-timing";
import type { ResurfacingWhyNowVerdict } from "@/types/resurfacing-why-now";

export type EmotionalRecognitionQaClass =
  | "earned_specific"
  | "vague_generic"
  | "creepy_overreach"
  | "too_soon"
  | "too_late"
  | "obvious_low_value"
  | "strong_recognition";

export interface EmotionalRecognitionQaChecklist {
  answersWhyNow: boolean;
  referencesPriorWords: boolean;
  wouldFeelRandom: boolean;
  tooTherapeutic: boolean;
  tooObvious: boolean;
  specificEnoughForRecognition: boolean;
}

export interface EmotionalRecognitionQaRow {
  noteId: string;
  qaClass: EmotionalRecognitionQaClass;
  callbackCopy: string;
  whyNowReason: string | null;
  confidenceScore: number;
  confidenceClassification: string;
  timingEligible: boolean;
  timingClass: string;
  timingSuppressReasons: string[];
  evidenceSignals: string[];
  sourceEntrySnippet: string | null;
  currentEntrySnippet: string | null;
  suppressReason: string | null;
  suggestedCopyRepair: string | null;
  checklist: EmotionalRecognitionQaChecklist;
  blocked: boolean;
}

export interface EmotionalRecognitionQaReport {
  generatedAt: string;
  hasData: boolean;
  totalReviewed: number;
  byClass: Record<EmotionalRecognitionQaClass, number>;
  rows: EmotionalRecognitionQaRow[];
  checklistSummary: Record<keyof EmotionalRecognitionQaChecklist, number>;
}

const RECENT_CANDIDATE_LIMIT = 24;
const THERAPY_COPY_RE =
  /\b(therapy|healing journey|unpack|process this|hold space|validate yourself|self-care|diagnos)\b/i;

const EMPTY_BY_CLASS: Record<EmotionalRecognitionQaClass, number> = {
  earned_specific: 0,
  vague_generic: 0,
  creepy_overreach: 0,
  too_soon: 0,
  too_late: 0,
  obvious_low_value: 0,
  strong_recognition: 0,
};

function entryById(entries: JournalEntry[], id?: string): JournalEntry | undefined {
  if (!id) return undefined;
  return entries.find((row) => row.id === id);
}

function entrySnippet(entry: JournalEntry | undefined, quote?: string): string | null {
  if (quote?.trim()) return quote.trim().slice(0, 180);
  if (!entry) return null;
  const transcript = entry.transcript?.trim();
  if (transcript) return transcript.slice(0, 180);
  const observation = entry.reflection.concreteObservation?.trim();
  if (observation) return observation.slice(0, 180);
  const phrase = entry.reflection.exactLanguagePattern?.trim();
  if (phrase) return phrase.slice(0, 180);
  return null;
}

function inferResurfacingKind(noteId: string): ResurfacingCopyInput["kind"] {
  if (/phrase|knows-me-phrase/i.test(noteId)) return "phrase_return";
  if (/calmer|quieter/i.test(noteId)) return "calmer_return";
  if (/heavier|worth_revisit|worth-revisit/i.test(noteId)) return "heavier_return";
  if (/before_quieter|before-quieter/i.test(noteId)) return "before_quieter";
  if (/first_topic|first-topic/i.test(noteId)) return "first_topic";
  if (/reads_differently|related_older/i.test(noteId)) return "reads_differently";
  return "reopen";
}

function isMoodOnlyResurface(note: MemoryNote, entries: JournalEntry[]): boolean {
  const kind = inferResurfacingKind(note.id);
  if (kind === "reopen") return false;
  return isMoodOrThemeOnlyResurface(
    kind,
    entryById(entries, note.pastEntryId),
    entryById(entries, note.entryId),
  );
}

function isTooTherapeutic(text: string): boolean {
  const trimmed = text.trim();
  if (!trimmed) return false;
  return (
    ADVICE_RESURFACING_RE.test(trimmed) ||
    OVERCLAIM_RESURFACING_RE.test(trimmed) ||
    THERAPY_COPY_RE.test(trimmed)
  );
}

function isCreepyOverreach(
  note: MemoryNote,
  confidence: ResurfacingConfidenceVerdict,
  whyNow: ResurfacingWhyNowVerdict,
): boolean {
  const copy = [note.text, whyNow.explanation ?? ""].filter(Boolean).join(" ");
  if (isBlockedResurfacingCopy(note.text)) return true;
  if (whyNow.explanation && isBlockedResurfacingCopy(whyNow.explanation)) return true;
  if (isTooTherapeutic(copy)) return true;
  if (confidence.falsePositiveRisks.includes("ignored_or_dismissed") && confidence.totalConfidence >= 70) {
    return true;
  }
  return false;
}

function isTooSoon(timing: ResurfacingTimingVerdict, gapDays: number): boolean {
  if (timing.timingClass === "too_early") return true;
  if (gapDays < 3) return true;
  return timing.suppressReasons.some((reason) =>
    ["same_day", "minimum_emotional_distance"].includes(reason),
  );
}

function isTooLate(
  timing: ResurfacingTimingVerdict,
  confidence: ResurfacingConfidenceVerdict,
  gapDays: number,
): boolean {
  if (timing.suppressReasons.includes("freshness_decay")) return true;
  if (gapDays >= 90 && !confidence.evidence.repeatedPhrase && confidence.evidenceSignalCount <= 2) {
    return true;
  }
  return false;
}

function classifyQaRow(
  note: MemoryNote,
  confidence: ResurfacingConfidenceVerdict,
  whyNow: ResurfacingWhyNowVerdict,
  timing: ResurfacingTimingVerdict,
  gapDays: number,
  entries: JournalEntry[],
): EmotionalRecognitionQaClass {
  if (isCreepyOverreach(note, confidence, whyNow)) return "creepy_overreach";
  if (isTooSoon(timing, gapDays)) return "too_soon";
  if (isTooLate(timing, confidence, gapDays)) return "too_late";

  const vagueSuppress = confidence.suppressReasons.some((reason) =>
    ["generic_copy", "no_why_now", "mood_only", "topic_recurrence_template"].includes(reason),
  );
  if (
    isGenericResurfacingCopy(note.text) ||
    vagueSuppress ||
    !whyNow.explanation ||
    isMoodOnlyResurface(note, entries)
  ) {
    return "vague_generic";
  }

  if (
    confidence.classification === "magic_candidate" ||
    (confidence.classification === "strong" &&
      whyNow.evidenceBacked &&
      (confidence.evidence.repeatedPhrase || confidence.evidence.repeatedConcern))
  ) {
    return "strong_recognition";
  }

  if (
    confidence.classification === "weak" ||
    confidence.classification === "suppress" ||
    (confidence.evidenceSignalCount <= 1 && !confidence.evidence.repeatedPhrase)
  ) {
    return "obvious_low_value";
  }

  if (confidence.classification === "plausible" || confidence.classification === "strong") {
    return "earned_specific";
  }

  return "obvious_low_value";
}

function collectEvidenceSignals(
  confidence: ResurfacingConfidenceVerdict,
  whyNow: ResurfacingWhyNowVerdict,
  timing: ResurfacingTimingVerdict,
): string[] {
  const signals = new Set<string>();
  for (const reason of confidence.reasons) signals.add(reason);
  if (confidence.evidence.repeatedPhrase) signals.add("repeated_phrase");
  if (confidence.evidence.repeatedConcern) signals.add("repeated_concern");
  if (confidence.evidence.moodShift) signals.add("mood_shift");
  if (confidence.evidence.priorInteraction) signals.add("prior_interaction");
  for (const entity of confidence.evidence.sharedEntities) {
    signals.add(`shared_entity:${entity}`);
  }
  for (const signal of whyNow.signals) signals.add(`why_now:${signal.kind}`);
  for (const reason of timing.reasons) signals.add(`timing:${reason}`);
  return [...signals];
}

function buildChecklist(
  note: MemoryNote,
  confidence: ResurfacingConfidenceVerdict,
  whyNow: ResurfacingWhyNowVerdict,
  entries: JournalEntry[],
): EmotionalRecognitionQaChecklist {
  const past = entryById(entries, note.pastEntryId);
  const hasPriorWords =
    Boolean(note.pastQuote?.trim()) ||
    confidence.evidence.repeatedPhrase ||
    Boolean(past?.reflection.exactLanguagePattern?.trim());

  const answersWhyNow = hasResurfacingWhyNow(note, entries) || Boolean(whyNow.explanation);
  const wouldFeelRandom =
    !whyNow.evidenceBacked &&
    confidence.evidenceSignalCount <= 1 &&
    !confidence.evidence.repeatedPhrase &&
    !confidence.evidence.repeatedConcern;

  const tooObvious =
    isGenericResurfacingCopy(note.text) ||
    (confidence.evidence.moodShift && !confidence.evidence.repeatedPhrase && !note.pastQuote?.trim());

  const specificEnoughForRecognition =
    confidence.evidence.repeatedPhrase ||
    (confidence.evidence.repeatedConcern && confidence.evidence.daysSincePrior >= 3) ||
    Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());

  return {
    answersWhyNow,
    referencesPriorWords: hasPriorWords,
    wouldFeelRandom,
    tooTherapeutic: isTooTherapeutic(note.text) || Boolean(whyNow.explanation && isTooTherapeutic(whyNow.explanation)),
    tooObvious,
    specificEnoughForRecognition,
  };
}

function suggestCopyRepair(
  note: MemoryNote,
  entries: JournalEntry[],
  confidence: ResurfacingConfidenceVerdict,
  gapDays: number,
): string | null {
  const needsRepair =
    confidence.suppressed ||
    isGenericResurfacingCopy(note.text) ||
    isBlockedResurfacingCopy(note.text);
  if (!needsRepair) return null;

  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (past && current) {
    return pickResurfacingHeadline({
      kind: inferResurfacingKind(note.id),
      gapDays,
      past,
      current,
      repeatedPhrase: confidence.evidence.repeatedPhrase,
    });
  }

  if (confidence.evidence.repeatedPhrase && gapDays >= 7) {
    return RESURFACING_COPY.similarDaysAgo(gapDays);
  }
  if (confidence.evidence.repeatedConcern) return RESURFACING_COPY.concernSofter;
  return RESURFACING_COPY.differentWords;
}

function gapDaysForNote(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (!past || !current) return 0;
  return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
}

function sortRecentCandidates(notes: MemoryNote[], entries: JournalEntry[]): MemoryNote[] {
  return [...notes].sort((left, right) => {
    const leftEntry = entryById(entries, left.entryId);
    const rightEntry = entryById(entries, right.entryId);
    const leftMs = leftEntry ? new Date(leftEntry.createdAt).getTime() : 0;
    const rightMs = rightEntry ? new Date(rightEntry.createdAt).getTime() : 0;
    return rightMs - leftMs;
  });
}

function primarySuppressReason(
  confidence: ResurfacingConfidenceVerdict,
  timing: ResurfacingTimingVerdict,
  whyNow: ResurfacingWhyNowVerdict,
): string | null {
  if (confidence.suppressReasons.length > 0) return confidence.suppressReasons[0];
  if (!timing.timingEligible && timing.suppressReasons.length > 0) return timing.suppressReasons[0];
  if (whyNow.blockedReason) return whyNow.blockedReason;
  return null;
}

function buildQaRow(note: MemoryNote, entries: JournalEntry[]): EmotionalRecognitionQaRow {
  const confidence = assessResurfacingConfidence(note, entries);
  const whyNow = assessResurfacingWhyNow(note, entries);
  const timing = assessResurfacingTiming(note, entries);
  const gapDays = gapDaysForNote(note, entries);
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);

  return {
    noteId: note.id,
    qaClass: classifyQaRow(note, confidence, whyNow, timing, gapDays, entries),
    callbackCopy: note.text,
    whyNowReason: whyNow.explanation ?? note.evidenceReason ?? null,
    confidenceScore: confidence.totalConfidence,
    confidenceClassification: confidence.classification,
    timingEligible: timing.timingEligible,
    timingClass: timing.timingClass,
    timingSuppressReasons: timing.suppressReasons,
    evidenceSignals: collectEvidenceSignals(confidence, whyNow, timing),
    sourceEntrySnippet: entrySnippet(past, note.pastQuote),
    currentEntrySnippet: entrySnippet(current, note.currentQuote),
    suppressReason: primarySuppressReason(confidence, timing, whyNow),
    suggestedCopyRepair: suggestCopyRepair(note, entries, confidence, gapDays),
    checklist: buildChecklist(note, confidence, whyNow, entries),
    blocked: confidence.suppressed || !timing.timingEligible || Boolean(whyNow.blockedReason),
  };
}

export function buildEmotionalRecognitionQaReport(): EmotionalRecognitionQaReport {
  const entries = getMemoryEligibleEntries();
  const candidates = sortRecentCandidates(
    collectResurfacingConfidenceCandidates(entries),
    entries,
  ).slice(0, RECENT_CANDIDATE_LIMIT);

  const rows = candidates.map((note) => buildQaRow(note, entries));
  const byClass = { ...EMPTY_BY_CLASS };
  for (const row of rows) {
    byClass[row.qaClass] += 1;
  }

  const checklistSummary: Record<keyof EmotionalRecognitionQaChecklist, number> = {
    answersWhyNow: 0,
    referencesPriorWords: 0,
    wouldFeelRandom: 0,
    tooTherapeutic: 0,
    tooObvious: 0,
    specificEnoughForRecognition: 0,
  };
  for (const row of rows) {
    for (const key of Object.keys(checklistSummary) as Array<keyof EmotionalRecognitionQaChecklist>) {
      if (row.checklist[key]) checklistSummary[key] += 1;
    }
  }

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0,
    totalReviewed: rows.length,
    byClass,
    rows,
    checklistSummary,
  };
}
