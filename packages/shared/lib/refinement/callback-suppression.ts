import type { MemoryNote } from "@/types/memory-note";

/** Low-contrast resurfacing note IDs — weak emotional contrast. */
export const LOW_CONTRAST_RESURFACE_ID =
  /^resurface-topic-|^resurface-entity-|^fam-resurface-similar/;

/** Routine or informational note IDs — deprioritize for surfacing. */
export const ROUTINE_RESURFACE_ID =
  /^rhythm-|^time-|^continuity-thread-|^continuity-recurring-|^archive-|^continuity-depth-|^familiarity-|^resurface-person-/;

/** Loop-style revisit IDs — often generic without quote contrast. */
export const REVISIT_LOOP_SUPPRESS_ID = /^resurface-loop-|^revisit-loop-|^continuity-callback-/;

export const SUPPRESSED_NOTE_ID_PATTERNS: RegExp[] = [
  LOW_CONTRAST_RESURFACE_ID,
  ROUTINE_RESURFACE_ID,
  REVISIT_LOOP_SUPPRESS_ID,
];

/** Generic callback copy — shared across hierarchy, revisit, and tuning. */
export const GENERIC_CALLBACK_TEXT_PATTERNS: RegExp[] = [
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
  /\byou came back to the same place\b/i,
  /\byou spoke about this the same way\b/i,
  /\bolder reflections are starting\b/i,
  /\bstarting to mean something\b/i,
  /\bkept coming back to a few things\b/i,
  /\btends to return\b/i,
  /\bweekly rhythm\b/i,
  /\bgap between these entries\b/i,
  /\bcame up again\b/i,
  /\bshowed up again\b/i,
  /\bkeeps showing up\b/i,
  /\bsame theme\b/i,
  /\bsame topic\b/i,
  /\breturned to this\b/i,
  /\bspoke about this again\b/i,
  /\bappeared again\b/i,
  /\bmoney returned\b/i,
  /\bwork appeared\b/i,
  /\byou came back to the same loop\b/i,
  /\byou came back to the same place\b/i,
  /\byou should\b/i,
  /\btry to\b/i,
  /\bcheck in with yourself\b/i,
  /\bhold space\b/i,
  /\bstreak\b/i,
  /\bproductivity\b/i,
  /\bclearly improved\b/i,
  /\bdefinitely changed\b/i,
];

export function noteIdMatchesSuppressedPattern(
  id: string,
  patterns: RegExp[] = SUPPRESSED_NOTE_ID_PATTERNS,
): boolean {
  return patterns.some((pattern) => pattern.test(id));
}

export function noteTextMatchesGenericPattern(
  text: string,
  patterns: RegExp[] = GENERIC_CALLBACK_TEXT_PATTERNS,
): boolean {
  const trimmed = text.trim();
  if (!trimmed) return true;
  return patterns.some((pattern) => pattern.test(trimmed));
}

export function shouldSuppressNoteByPattern(note: MemoryNote): boolean {
  if (!note.text.trim()) return true;
  if (noteIdMatchesSuppressedPattern(note.id)) return true;
  if (noteTextMatchesGenericPattern(note.text)) return true;
  return false;
}

/** Combined ID patterns for revisit reward gating (superset). */
export const REVISIT_REWARD_SUPPRESS_ID = new RegExp(
  [
    ROUTINE_RESURFACE_ID.source,
    LOW_CONTRAST_RESURFACE_ID.source,
    REVISIT_LOOP_SUPPRESS_ID.source,
  ].join("|"),
);

export const REVISIT_REWARD_SUPPRESS_TEXT = new RegExp(
  GENERIC_CALLBACK_TEXT_PATTERNS.map((pattern) => pattern.source).join("|"),
  "i",
);
