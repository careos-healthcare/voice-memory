export interface UnresolvedThreadSignal {
  anchorPhrases: string[];
  title: string;
  concernLabel?: string;
}

const UNRESOLVED_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
  { pattern: /\bi need to\b/i, label: "Need to follow through" },
  { pattern: /\bi keep avoiding\b/i, label: "Keeps avoiding" },
  { pattern: /\bi don'?t know what to do about\b/i, label: "Unsure what to do" },
  { pattern: /\bi'?m waiting for\b/i, label: "Waiting" },
  { pattern: /\bi still need to\b/i, label: "Still needs doing" },
  { pattern: /\bthis keeps coming back\b/i, label: "Keeps coming back" },
];

function splitSentences(text: string): string[] {
  return text
    .split(/(?<=[.!?])\s+|\n+/)
    .map((part) => part.trim())
    .filter((part) => part.length > 8);
}

function sentenceForMatch(text: string, pattern: RegExp): string | null {
  for (const sentence of splitSentences(text)) {
    if (pattern.test(sentence)) return sentence;
  }
  if (pattern.test(text)) {
    const trimmed = text.trim();
    return trimmed.length > 160 ? `${trimmed.slice(0, 157)}…` : trimmed;
  }
  return null;
}

function buildTitle(anchorPhrase: string, fallback: string): string {
  const compact = anchorPhrase.replace(/\s+/g, " ").trim();
  if (compact.length <= 48) return compact;
  return fallback;
}

/** Conservative detection — only explicit unresolved language in the transcript. */
export function detectUnresolvedThread(transcript: string): UnresolvedThreadSignal | null {
  const text = transcript.trim();
  if (text.length < 12) return null;

  const anchorPhrases: string[] = [];
  let concernLabel: string | undefined;
  let title = "Open thread";

  for (const { pattern, label } of UNRESOLVED_PATTERNS) {
    const phrase = sentenceForMatch(text, pattern);
    if (!phrase) continue;
    if (!anchorPhrases.includes(phrase)) anchorPhrases.push(phrase);
    if (!concernLabel) {
      concernLabel = label;
      title = buildTitle(phrase, label);
    }
  }

  if (anchorPhrases.length === 0) return null;

  return {
    anchorPhrases,
    title,
    concernLabel,
  };
}

export function hasUnresolvedThreadLanguage(transcript: string): boolean {
  return detectUnresolvedThread(transcript) !== null;
}
