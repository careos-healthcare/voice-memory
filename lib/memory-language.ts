/** Canonical user-facing phrasing — quiet memory, not an AI product. */

export const MEMORY_LANGUAGE = {
  youSaidBefore: "You said this before.",
  thisCameBack: "This came back.",
  yourOwnWords: "Your own words",
  wordsReturned: "Your own words came back.",
  leftIndirect: "You left something indirect.",
  twoTruths: "Two things you said did not line up.",
  whatStoodOut: "What stood out",
  phraseReturned: "A phrase that returned",
  notEnoughYet: "Not enough yet for a memory timeline.",
} as const;

/** Substrings that should not appear in user-facing app/components copy. */
export const BANNED_USER_MEMORY_PHRASES = [
  "ai journal",
  "ai-powered",
  "powered by ai",
  "insight engine",
  "pattern analysis",
  "emotional data",
  "analytics dashboard",
  "metrics dashboard",
  "intelligence layer",
  "memory intelligence",
  "generated insight",
  "we detected",
  "our system",
  "the system recommends",
  "your score",
  "performance score",
  "speaker expresses",
  "mood snapshot",
  "dominant mood",
  "emotional intensity trend",
  "mood tracker",
  "intensity/10",
] as const;
