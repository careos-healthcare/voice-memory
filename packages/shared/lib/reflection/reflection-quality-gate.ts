import type { JournalEntry } from "@/types/journal";

/** Minimum non-filler words before a reflection surfaces on homepage/journal. */
export const MIN_MEANINGFUL_WORDS = 5;

const STOP_WORDS = new Set([
  "a",
  "an",
  "the",
  "and",
  "or",
  "but",
  "so",
  "to",
  "of",
  "in",
  "on",
  "at",
  "it",
  "is",
  "was",
  "are",
  "be",
  "i",
  "you",
  "we",
  "my",
  "me",
  "uh",
  "um",
  "like",
  "just",
  "really",
  "very",
]);

const NUMERIC_RUN_RE = /(?:\b\d+\b[,.]?\s*){3,}/;
const COUNTING_RE =
  /\b(one|two|three|four|five|six|seven|eight|nine|ten)\b[,.]?\s+(one|two|three|four|five|six|seven|eight|nine|ten)\b/i;
const DIGIT_SEQUENCE_RE = /\b1\s*[,.\s]\s*2\s*[,.\s]\s*3\b/;
const FILLER_REPEAT_RE = /\b(\w{2,})(?:\s+\1\b){2,}/i;
const FILLER_ONLY_RE = /^(?:please|okay|ok|yeah|yes|no|um|uh|test)+\.?$/i;

const JUNK_PHRASE_RES: RegExp[] = [
  /\bthank\s*you\s*for\s*watching\b/i,
  /\bthanks\s*for\s*watching\b/i,
  /\bthis\s+is\s+(just\s+)?a\s+test\b/i,
  /\bonly\s+a\s+test\b/i,
  /\btest\s+test\b/i,
  /\btesting\s+one\s+two\b/i,
  /\blorem\s+ipsum\b/i,
  /\bsubscribe\b/i,
  /\blike\s+and\s+subscribe\b/i,
];

function normalized(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

export function meaningfulWordCount(text: string): number {
  const words = normalized(text)
    .toLowerCase()
    .split(/\s+/)
    .map((w) => w.replace(/[^a-z0-9']/g, ""))
    .filter((w) => w.length > 1);
  return words.filter((w) => !STOP_WORDS.has(w)).length;
}

/** Transcript is test/junk — hide from primary UI but keep the entry. */
export function isJunkReflectionTranscript(text: string): boolean {
  const t = normalized(text);
  if (!t) return true;
  if (t.length < 8) return true;
  if (/^test\.?$/i.test(t)) return true;
  if (FILLER_ONLY_RE.test(t)) return true;
  if (FILLER_REPEAT_RE.test(t)) return true;
  if (NUMERIC_RUN_RE.test(t)) return true;
  if (COUNTING_RE.test(t)) return true;
  if (DIGIT_SEQUENCE_RE.test(t)) return true;
  for (const re of JUNK_PHRASE_RES) {
    if (re.test(t)) return true;
  }
  const words = t.split(/\s+/).filter(Boolean);
  if (words.length < 3) return true;
  if (meaningfulWordCount(t) < MIN_MEANINGFUL_WORDS) return true;
  const digitChars = (t.match(/\d/g) ?? []).length;
  if (digitChars / t.length > 0.3) return true;
  const alphaChars = (t.match(/[a-z]/gi) ?? []).length;
  if (alphaChars < 10) return true;
  return false;
}

/** Entry eligible for journal cards, homepage resurfacing, and continuity quotes. */
export function isPrimarySurfacedReflection(entry: JournalEntry): boolean {
  if (entry.reflectionPending === true) return false;
  const transcript = entry.transcript?.trim();
  if (!transcript) return false;
  return !isJunkReflectionTranscript(transcript);
}

/** Snippet for list cards — null when junk should not be quoted. */
export function primaryReflectionSnippet(
  entry: JournalEntry,
  maxLen = 160,
): string | null {
  if (!isPrimarySurfacedReflection(entry)) return null;
  const transcript = entry.transcript?.trim();
  if (!transcript) return null;
  const slice = transcript.slice(0, maxLen);
  return transcript.length > maxLen ? `${slice}…` : slice;
}
