import { detectRewriteCandidateFlags } from "@/lib/debug/callback-rewrite-detection";
import { shouldSuppressNoteByPattern } from "@/lib/refinement/callback-suppression";
import { isTopicRecurrenceCopy } from "@/lib/refinement/knows-me-moments";
import { scoreMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import { SCORE_MEMORY_HIERARCHY } from "@/lib/refinement/score-thresholds";
import { readFalsePositiveSilenceContext } from "@/lib/refinement/silence-calibration";
import {
  qualifiesRevisitQuoteContrast,
  quoteSimilarity,
} from "@/lib/refinement/then-vs-now-quotes";
import type {
  FalsePositiveAssessmentInput,
  FalsePositiveReason,
  FalsePositiveSourceModule,
  FalsePositiveVerdict,
} from "@/types/false-positive-suppression";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const OVERCLAIM_CHANGE_RE =
  /\b(completely changed|totally different|transformed|dramatically|profound shift|deeply shifted|major shift|everything changed|fundamentally different)\b/i;

const GENERATED_INTERPRETATION_RE =
  /\b(you seem to be|it appears you|this suggests you|emotionally you|your inner|processing this|working through|underlying feeling)\b/i;

const TOPIC_ONLY_ID_RE =
  /^resurface-topic-|^resurface-entity-|^resurface-phrase-|^fam-resurface-similar|^continuity-thread-|^continuity-recurring-|^rhythm-|^time-/;

const WEAK_CONTRAST_TEXT_RE =
  /\b(this changed|what changed|appeared again|similar theme|same topic|worth revisiting|older reflection)\b/i;

function missingFromReasons(reasons: FalsePositiveReason[]): string[] {
  const missing: string[] = [];

  if (reasons.includes("weak_emotional_contrast")) {
    missing.push("Clear emotional contrast between then and now");
  }
  if (reasons.includes("topic_recurrence_only")) {
    missing.push("Evidence beyond topic recurrence");
  }
  if (reasons.includes("could_apply_to_many")) {
    missing.push("Specific wording tied to this archive");
  }
  if (reasons.includes("shown_recently")) {
    missing.push("Fresh timing — same idea was shown recently");
  }
  if (reasons.includes("quotes_not_different")) {
    missing.push("Before/after quotes that read differently");
  }
  if (reasons.includes("single_weak_signal")) {
    missing.push("Multiple reinforcing signals, not one weak cue");
  }
  if (reasons.includes("ignored_similar_before")) {
    missing.push("User engagement with a similar note");
  }
  if (reasons.includes("overclaims_change")) {
    missing.push("Grounded change evidence, not broad claims");
  }
  if (reasons.includes("generated_interpretation")) {
    missing.push("Archive-grounded observation, not interpretation");
  }
  if (reasons.includes("suppressed_pattern")) {
    missing.push("Pass shared suppression patterns");
  }
  if (reasons.includes("weak_hierarchy")) {
    missing.push("Stronger hierarchy score");
  }

  return missing;
}

/** Assess whether a note should stay silent — prefer quiet over emotionally wrong copy. */
export function assessFalsePositive(input: FalsePositiveAssessmentInput): FalsePositiveVerdict {
  const { note, entries = [] } = input;
  const reasons: FalsePositiveReason[] = [];
  const text = note.text.trim();

  if (!text) {
    return {
      suppressed: true,
      reasons: ["weak_hierarchy"],
      missingEvidence: ["Non-empty note text"],
      rewriteFlags: [],
    };
  }

  if (shouldSuppressNoteByPattern(note)) {
    reasons.push("suppressed_pattern");
  }

  if (isTopicRecurrenceCopy(text) || TOPIC_ONLY_ID_RE.test(note.id)) {
    reasons.push("topic_recurrence_only");
  }

  const rewriteFlags = detectRewriteCandidateFlags({
    text,
    beforeQuote: note.pastQuote,
    afterQuote: note.currentQuote,
  });

  if (rewriteFlags.includes("could_apply_to_many")) {
    reasons.push("could_apply_to_many");
  }

  if (
    rewriteFlags.includes("lacks_emotional_contrast") ||
    (note.pastQuote?.trim() &&
      note.currentQuote?.trim() &&
      quoteSimilarity(note.pastQuote, note.currentQuote) >= 0.78)
  ) {
    reasons.push("quotes_not_different");
  }

  if (
    note.pastQuote?.trim() &&
    note.currentQuote?.trim() &&
    entries.length > 0 &&
    !qualifiesRevisitQuoteContrast(
      note.pastQuote,
      note.currentQuote,
      note.pastEntryId
        ? entries.find((entry) => entry.id === note.pastEntryId)
        : undefined,
      note.entryId ? entries.find((entry) => entry.id === note.entryId) : undefined,
    )
  ) {
    reasons.push("weak_emotional_contrast");
  }

  if (!note.pastQuote?.trim() && !note.currentQuote?.trim() && WEAK_CONTRAST_TEXT_RE.test(text)) {
    reasons.push("weak_emotional_contrast");
  }

  if (
    rewriteFlags.includes("generic_wording") ||
    rewriteFlags.includes("templated") ||
    rewriteFlags.includes("over_explains") ||
    GENERATED_INTERPRETATION_RE.test(text)
  ) {
    reasons.push("generated_interpretation");
  }

  if (OVERCLAIM_CHANGE_RE.test(text) && !note.pastQuote?.trim()) {
    reasons.push("overclaims_change");
  }

  const hierarchy = entries.length > 0 ? scoreMemoryHierarchy(note, entries) : undefined;
  if (hierarchy && hierarchy.total < SCORE_MEMORY_HIERARCHY - 4) {
    reasons.push("weak_hierarchy");
  }

  const hasQuotes = Boolean(note.pastQuote?.trim() || note.currentQuote?.trim());
  const preferredSignals = hierarchy?.preferred.length ?? 0;
  if (
    note.confidence < 66 &&
    !hasQuotes &&
    preferredSignals <= 1 &&
    (!hierarchy || hierarchy.total < SCORE_MEMORY_HIERARCHY + 6)
  ) {
    reasons.push("single_weak_signal");
  }

  const silence = readFalsePositiveSilenceContext(text, note.id);
  if (silence.shownRecently) {
    reasons.push("shown_recently");
  }
  if (silence.ignoredSimilarBefore) {
    reasons.push("ignored_similar_before");
  }

  const uniqueReasons = [...new Set(reasons)];
  const suppressed = uniqueReasons.length > 0;

  return {
    suppressed,
    reasons: uniqueReasons,
    missingEvidence: missingFromReasons(uniqueReasons),
    rewriteFlags,
    hierarchyScore: hierarchy?.total,
  };
}

export function isFalsePositiveNote(
  note: MemoryNote,
  entries: JournalEntry[] = [],
  sourceModule?: FalsePositiveAssessmentInput["sourceModule"],
): boolean {
  return assessFalsePositive({ note, entries, sourceModule }).suppressed;
}

export function filterFalsePositiveNotes(
  notes: MemoryNote[],
  entries: JournalEntry[],
  sourceModule?: FalsePositiveAssessmentInput["sourceModule"],
): MemoryNote[] {
  return notes.filter(
    (note) => !isFalsePositiveNote(note, entries, sourceModule),
  );
}

/** Return note only if it clears false-positive suppression — otherwise null. */
export function guardSurfacedNote(
  note: MemoryNote | null,
  entries: JournalEntry[],
  sourceModule?: FalsePositiveAssessmentInput["sourceModule"],
): MemoryNote | null {
  if (!note) return null;
  if (isFalsePositiveNote(note, entries, sourceModule)) return null;
  return note;
}

export function sourceModuleFromNoteId(noteId: string): FalsePositiveSourceModule {
  if (noteId.startsWith("knows-me-") || noteId.startsWith("revisit-reward")) return "knows_me";
  if (noteId.startsWith("resurface-") || noteId.startsWith("fam-resurface-")) return "resurfacing";
  if (noteId.startsWith("followup-") || noteId.startsWith("continuation-")) return "follow_up";
  if (noteId.startsWith("archive-gravity-")) return "archive_gravity";
  if (noteId.startsWith("milestone-")) return "milestone";
  if (noteId.startsWith("chapter-")) return "chaptering";
  if (noteId.startsWith("voice-identity-")) return "voice_identity";
  if (noteId.startsWith("living-resurface-")) return "living_resurfacing";
  if (noteId.startsWith("delayed-payoff-")) return "delayed_payoff";
  return "unknown";
}
