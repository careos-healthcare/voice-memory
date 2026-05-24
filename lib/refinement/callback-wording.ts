import { isFalsePositiveNote } from "@/lib/refinement/false-positive-suppression";
import { detectRewriteCandidateFlags } from "@/lib/debug/callback-rewrite-detection";
import { shouldSuppressNoteByPattern } from "@/lib/refinement/callback-suppression";
import { isTopicRecurrenceCopy } from "@/lib/refinement/knows-me-moments";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

/** Preferred temporal copy — internal rewrite targets from callback survival review. */
export const PREFERRED_CALLBACK_COPY = {
  carryingDifferently: "You were carrying this differently then.",
  notNamedYet: "You had not named it yet.",
  furtherAway: "You sound further away from it now.",
  usedToTakeRoom: "This used to take up more room.",
  samePlace: "You came back to the same place.",
} as const;

const EXACT_REWRITE_MAP: Array<{ re: RegExp; text: string }> = [
  { re: /\bthis changed over time\b/i, text: PREFERRED_CALLBACK_COPY.carryingDifferently },
  { re: /\bthis shifted over time\b/i, text: PREFERRED_CALLBACK_COPY.carryingDifferently },
  { re: /\bwhat changed\b/i, text: PREFERRED_CALLBACK_COPY.carryingDifferently },
  { re: /\ban older reflection may feel different\b/i, text: PREFERRED_CALLBACK_COPY.carryingDifferently },
  { re: /\bolder reflections (are )?(starting|beginning) to mean\b/i, text: PREFERRED_CALLBACK_COPY.carryingDifferently },
  { re: /\bworth revisiting\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bworth returning to\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bnot named (this )?directly yet\b/i, text: PREFERRED_CALLBACK_COPY.notNamedYet },
  { re: /\byou had not named this\b/i, text: PREFERRED_CALLBACK_COPY.notNamedYet },
  { re: /\byou sound calmer now\b/i, text: PREFERRED_CALLBACK_COPY.furtherAway },
  { re: /\bmore settled now\b/i, text: PREFERRED_CALLBACK_COPY.furtherAway },
  { re: /\bthis was before it shifted\b/i, text: PREFERRED_CALLBACK_COPY.carryingDifferently },
  { re: /\bthis used to feel heavier\b/i, text: PREFERRED_CALLBACK_COPY.usedToTakeRoom },
  { re: /\bmore pressure before\b/i, text: PREFERRED_CALLBACK_COPY.usedToTakeRoom },
  { re: /\btopic appeared again\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bappeared again\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bkeeps showing up\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bcame up again\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bshowed up again\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bsame theme\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bsame topic\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\breturned to this\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bspoke about this again\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bthis came back softly\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
  { re: /\bhas been quiet for a while\b/i, text: PREFERRED_CALLBACK_COPY.furtherAway },
  { re: /\bmean something different\b/i, text: PREFERRED_CALLBACK_COPY.carryingDifferently },
  { re: /\bkept coming back to a few things\b/i, text: PREFERRED_CALLBACK_COPY.samePlace },
];

const SUPPRESS_TEXT: RegExp[] = [
  /^this changed\.?$/i,
  /^what changed\.?$/i,
  /\ban older reflection\b/i,
  /\bworth revisiting\b/i,
  /\bworth returning to\b/i,
  /\bolder reflection(s)? (may|might|can)\b/i,
  /\btopic appeared\b/i,
  /\bsimilar theme\b/i,
  /\bdominant theme\b/i,
  /\brecurring pattern\b/i,
  /\bthreads can start appearing\b/i,
  /\bchanges may begin to surface\b/i,
];

const SUPPRESS_ID: RegExp[] = [
  /^resurface-topic-/,
  /^resurface-entity-/,
  /^resurface-phrase-/,
  /^fam-resurface-similar/,
  /^continuity-thread-/,
  /^continuity-recurring-/,
  /^archive-/,
  /^continuity-depth-/,
];

function signalFromNote(note: MemoryNote): string {
  if (/calmer|quieter|further|settled/i.test(note.text)) return "calmer";
  if (/named|direct|not named/i.test(note.text)) return "named";
  if (/heavier|room|space|pressure/i.test(note.text)) return "weight";
  if (/same place|same loop|came back/i.test(note.text)) return "return";
  return "contrast";
}

function rewriteBySignal(note: MemoryNote): string | null {
  const signal = signalFromNote(note);
  switch (signal) {
    case "calmer":
      return PREFERRED_CALLBACK_COPY.furtherAway;
    case "named":
      return PREFERRED_CALLBACK_COPY.notNamedYet;
    case "weight":
      return PREFERRED_CALLBACK_COPY.usedToTakeRoom;
    case "return":
      return PREFERRED_CALLBACK_COPY.samePlace;
    default:
      return PREFERRED_CALLBACK_COPY.carryingDifferently;
  }
}

export function shouldSuppressCallbackCopy(
  note: MemoryNote,
  entries: JournalEntry[] = [],
): boolean {
  const text = note.text.trim();
  if (isFalsePositiveNote(note, entries)) return true;
  if (shouldSuppressNoteByPattern(note)) return true;
  if (isTopicRecurrenceCopy(text)) return true;

  const flags = detectRewriteCandidateFlags({ text });
  if (
    flags.includes("could_apply_to_many") &&
    flags.includes("lacks_specificity") &&
    !note.pastQuote?.trim()
  ) {
    return true;
  }

  return false;
}

/** Rewrite weak recurring callback lines toward personal, temporal wording. */
export function tuneCallbackWording(note: MemoryNote, _entries: JournalEntry[]): MemoryNote {
  if (shouldSuppressCallbackCopy(note)) return note;

  const text = note.text.trim();
  for (const row of EXACT_REWRITE_MAP) {
    if (row.re.test(text)) {
      return { ...note, text: row.text };
    }
  }

  const flags = detectRewriteCandidateFlags({
    text,
    beforeQuote: note.pastQuote,
    afterQuote: note.currentQuote,
  });

  if (
    flags.length >= 2 &&
    (flags.includes("generic_wording") ||
      flags.includes("templated") ||
      flags.includes("could_apply_to_many"))
  ) {
    const rewritten = rewriteBySignal(note);
    if (rewritten && rewritten !== text) {
      return { ...note, text: rewritten };
    }
  }

  return note;
}

export function tuneCallbackPool(notes: MemoryNote[], entries: JournalEntry[]): MemoryNote[] {
  return notes
    .map((note) => tuneCallbackWording(note, entries))
    .filter((note) => !shouldSuppressCallbackCopy(note, entries));
}
