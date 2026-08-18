/** Coaching / therapy / motivation phrases — reject synthesis output containing these. */
export const ARCHIVE_SYNTHESIS_BANNED_PHRASES = [
  "you should",
  "you need to",
  "try to",
  "consider trying",
  "work on",
  "action plan",
  "next steps",
  "best self",
  "healing journey",
  "inner work",
  "breakthrough",
  "transform yourself",
  "stay strong",
  "proud of you",
  "believe in yourself",
  "self-care journey",
  "hold space",
  "inner child",
  "trauma",
  "attachment style",
  "diagnose",
  "therapy",
  "coach",
  "motivat",
  "habit streak",
  "level up",
  "optimize your",
  "journey toward",
  "permission to",
  "trust the process",
  "honor your feelings",
] as const;

export function findBannedPhrase(text: string): string | null {
  const lower = text.toLowerCase();
  for (const phrase of ARCHIVE_SYNTHESIS_BANNED_PHRASES) {
    if (lower.includes(phrase)) return phrase;
  }
  return null;
}
