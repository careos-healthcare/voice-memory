import { isFalsePositiveNote } from "@/lib/refinement/false-positive-suppression";
import { calibrateFollowupPrompt } from "@/lib/refinement/silence-calibration";
import { continuationBoostForNote } from "@/lib/retention/loop-optimization";
import { recordFollowUpPrompt } from "@/lib/sync/cross-device-continuity";
import {
  CONTINUATION_COPY,
  gatherContinuationCandidates,
  storeContinuationMeta,
  type ContinuationKind,
} from "@/lib/conversation/continuation-loops";
import type {
  FollowupCandidate,
  FollowupPrompt,
  FollowupSource,
} from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export const FOLLOWUP_PROMPT_KEY = "voicememory_followup_prompt";

const STRONG_MIN = 62;
const EVIDENCE_MIN = 64;

const BANNED_PROMPT_RE =
  /\b(analysis|insight|therapy|coach|should|try to|recommend|diagnos|assistant)\b/i;

const SOURCE_PRIORITY: Record<FollowupSource, number> = {
  then_vs_now: 100,
  continuation: 96,
  revisit_contrast: 94,
  partial_return: 90,
  unfinished: 88,
  recovery: 86,
  continuity: 84,
  resurfacing: 80,
  familiarity_resurfacing: 78,
  revisitation: 76,
};

function isRecoveryNote(note: MemoryNote): boolean {
  return (
    note.id.startsWith("recovery-") ||
    note.id.startsWith("moment-recovery-") ||
    /\b(recovery|calmer|quieter|resolved)\b/i.test(note.text)
  );
}

/** Classify whether a visible memory note qualifies for a follow-up prompt. */
export function classifyFollowupSource(note: MemoryNote): FollowupSource | null {
  if (note.id.startsWith("continuation-")) return "continuation";
  if (note.id.startsWith("tvn-")) return "then_vs_now";
  if (note.id.startsWith("continuity-")) return "continuity";
  if (note.id.startsWith("resurface-")) return "resurfacing";
  if (note.id.startsWith("revisit-")) return "revisitation";
  if (note.id.startsWith("fam-resurface-")) return "familiarity_resurfacing";
  if (isRecoveryNote(note)) return "recovery";

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    return "then_vs_now";
  }

  return null;
}

function hasStrongEvidence(note: MemoryNote): boolean {
  const hasQuotes = Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());
  const hasDates = Boolean(note.pastDateLabel && note.currentDateLabel);
  if (hasQuotes) return true;
  if (hasDates && note.confidence >= EVIDENCE_MIN) return true;
  if (note.text.trim().length >= 24 && note.confidence >= EVIDENCE_MIN) return true;
  return false;
}

function isEligibleNote(note: MemoryNote): boolean {
  if (note.confidence < STRONG_MIN) return false;
  if (!hasStrongEvidence(note)) return false;
  return classifyFollowupSource(note) !== null;
}

function sourceForContinuationKind(kind: ContinuationKind): FollowupSource {
  switch (kind) {
    case "revisit_contrast":
      return "revisit_contrast";
    case "partial_return":
    case "revisit_no_reflection":
      return "partial_return";
    case "unfinished_thought":
    case "ending_uncertainty":
    case "repeated_unresolved":
      return "unfinished";
    default:
      return "continuation";
  }
}

function promptForSource(note: MemoryNote, source: FollowupSource): string {
  if (note.id.startsWith("continuation-")) {
    return note.text.trim();
  }

  if (source === "then_vs_now" || (note.pastQuote && note.currentQuote)) {
    return CONTINUATION_COPY.sayBackToSelf;
  }

  if (source === "continuity") {
    const text = note.text.toLowerCase();
    if (/\b(stopped|left off)\b/i.test(text)) return CONTINUATION_COPY.stoppedHere;
    if (/\b(unresolved|unfinished|left this)\b/i.test(text)) {
      return CONTINUATION_COPY.neverFinished;
    }
    if (/\b(came back|returned)\b/i.test(text)) return CONTINUATION_COPY.cameBackNotFully;
    if (/\b(different|changed|differently)\b/i.test(text)) {
      return CONTINUATION_COPY.sayBackToSelf;
    }
    return CONTINUATION_COPY.moreToSay;
  }

  if (source === "recovery" || /\b(calmer|quieter|recovery)\b/i.test(note.text)) {
    return CONTINUATION_COPY.moreToSay;
  }

  if (/\b(return|came back|again|revisit)\b/i.test(note.text)) {
    return CONTINUATION_COPY.cameBackNotFully;
  }

  if (/\b(different|changed|differently|carrying)\b/i.test(note.text)) {
    return CONTINUATION_COPY.sayBackToSelf;
  }

  if (/\b(familiar|before|then|now|older)\b/i.test(note.text)) {
    return CONTINUATION_COPY.moreToSay;
  }

  return CONTINUATION_COPY.moreToSay;
}

function scoreCandidate(candidate: FollowupCandidate): number {
  return candidate.priority + candidate.note.confidence + continuationBoostForNote(candidate.note.id);
}

function continuationToNote(candidate: ReturnType<typeof gatherContinuationCandidates>[number]): MemoryNote {
  return {
    id: candidate.id,
    text: candidate.text,
    category: "returned",
    confidence: candidate.strength,
    pastQuote: candidate.pastQuote,
    currentQuote: candidate.currentQuote,
    pastDateLabel: candidate.pastDateLabel,
    currentDateLabel: candidate.currentDateLabel,
    pastEntryId: candidate.pastEntryId,
    entryId: candidate.entryId,
  };
}

/** Build follow-up candidates from visible memory notes. */
export function gatherFollowupCandidates(notes: MemoryNote[]): FollowupCandidate[] {
  const candidates: FollowupCandidate[] = [];

  for (const note of notes) {
    if (!isEligibleNote(note)) continue;
    const source = classifyFollowupSource(note);
    if (!source) continue;

    candidates.push({
      note,
      source,
      priority: SOURCE_PRIORITY[source],
    });
  }

  return candidates;
}

function gatherContinuationFollowupCandidates(
  entries: JournalEntry[],
  notes: MemoryNote[],
  entryId?: string,
): FollowupCandidate[] {
  return gatherContinuationCandidates(entries, notes, entryId).map((candidate) => {
    const source = sourceForContinuationKind(candidate.kind);
    return {
      note: continuationToNote(candidate),
      source,
      priority: SOURCE_PRIORITY[source],
    };
  });
}

/** Pick at most one grounded follow-up prompt — unfinished conversation, not coaching. */
export function buildFollowupPrompt(
  notes: MemoryNote[],
  entries: JournalEntry[] = [],
  entryId?: string,
): FollowupPrompt | null {
  const candidates = [
    ...gatherContinuationFollowupCandidates(entries, notes, entryId),
    ...gatherFollowupCandidates(notes),
  ].filter(
    (candidate) => !isFalsePositiveNote(candidate.note, entries, "follow_up"),
  );

  if (candidates.length === 0) return null;

  const best = [...candidates].sort((a, b) => scoreCandidate(b) - scoreCandidate(a))[0];
  const text = (
    best.note.id.startsWith("continuation-")
      ? best.note.text
      : promptForSource(best.note, best.source)
  ).trim();

  if (text.length < 8 || BANNED_PROMPT_RE.test(text)) return null;

  return calibrateFollowupPrompt(
    {
      id: `followup-${best.source}-${best.note.id}`,
      text,
      source: best.source,
      noteId: best.note.id,
      noteText: best.note.text,
      strength: scoreCandidate(best),
    },
    notes,
  );
}

export function storeFollowupPrompt(prompt: FollowupPrompt | string): void {
  if (typeof window === "undefined") return;
  const text = typeof prompt === "string" ? prompt : prompt.text;
  sessionStorage.setItem(FOLLOWUP_PROMPT_KEY, text);
  if (typeof prompt !== "string") {
    storeContinuationMeta(prompt.id, prompt.noteId);
    recordFollowUpPrompt({
      id: prompt.id,
      text: prompt.text,
      noteId: prompt.noteId,
    });
  }
}

export function consumeStoredFollowupPrompt(): string | null {
  if (typeof window === "undefined") return null;
  const text = sessionStorage.getItem(FOLLOWUP_PROMPT_KEY);
  if (text) sessionStorage.removeItem(FOLLOWUP_PROMPT_KEY);
  return text;
}

/** Build a recorder-only continuation line from the archive. */
export function buildRecorderContinuationPrompt(
  entries: JournalEntry[],
): FollowupPrompt | null {
  return buildFollowupPrompt([], entries);
}
