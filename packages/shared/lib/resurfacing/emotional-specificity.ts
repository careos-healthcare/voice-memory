/** Banned vague copy on user-facing surfaces — keep resurfacing concrete. */

export const EMOTIONAL_SPECIFICITY_BANNED_PHRASES = [
  "patterns may emerge",
  "journey",
  "insights",
  "growth",
  "reflective mirror",
  "memory intelligence",
  "pattern intelligence",
  "intelligence layer",
  "discover patterns",
  "your inner journey",
  "healing journey",
  "growth journey",
  "self-awareness journey",
] as const;

export const EMOTIONAL_SPECIFICITY_BANNED_RE = [
  /\bpatterns may emerge\b/i,
  /\b(?:healing|growth|inner|self[- ]?care)\s+journey\b/i,
  /\byour journey\b/i,
  /\breflective mirror\b/i,
  /\bmemory intelligence\b/i,
  /\bpattern intelligence\b/i,
  /\bintelligence layer\b/i,
  /\b(?:unlock|discover)\s+(?:your\s+)?insights?\b/i,
  /\bemotional growth\b/i,
  /\bself[- ]?growth\b/i,
  /\breflective intelligence\b/i,
] as const;

export function isEmotionallySpecificCopy(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed) return false;
  const lower = trimmed.toLowerCase();
  for (const phrase of EMOTIONAL_SPECIFICITY_BANNED_PHRASES) {
    if (lower.includes(phrase)) return false;
  }
  for (const re of EMOTIONAL_SPECIFICITY_BANNED_RE) {
    if (re.test(trimmed)) return false;
  }
  return true;
}
