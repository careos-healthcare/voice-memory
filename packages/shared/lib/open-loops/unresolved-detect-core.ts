import { recordFunctionInvocation } from "@/lib/open-loops/open-loop-performance";

export interface UnresolvedThreadSignal {
  anchorPhrases: string[];
  title: string;
  concernLabel?: string;
  matchedLabels: string[];
}

const UNRESOLVED_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
  { pattern: /\bhaunted\b/i, label: "Haunted" },
  { pattern: /\bscared\b/i, label: "Scared" },
  { pattern: /\bafraid\b/i, label: "Afraid" },
  { pattern: /\bworried\b/i, label: "Worried" },
  { pattern: /\banxious\b/i, label: "Anxious" },
  { pattern: /\boverwhelmed\b/i, label: "Overwhelmed" },
  { pattern: /\bstuck\b/i, label: "Stuck" },
  { pattern: /\buncertain\b/i, label: "Uncertain" },
  { pattern: /\bavoiding\b/i, label: "Avoiding" },
  { pattern: /\bpressure\b/i, label: "Pressure" },
  { pattern: /\bkeeps returning\b/i, label: "Keeps returning" },
  { pattern: /\bcan'?t stop thinking\b/i, label: "Keeps circling" },
  { pattern: /\bi need to\b/i, label: "Need to follow through" },
  { pattern: /\bi keep avoiding\b/i, label: "Keeps avoiding" },
  { pattern: /\bi don'?t know what to do about\b/i, label: "Unsure what to do" },
  { pattern: /\bi'?m waiting for\b/i, label: "Waiting" },
  { pattern: /\bi still need to\b/i, label: "Still needs doing" },
  { pattern: /\bthis keeps coming back\b/i, label: "Keeps coming back" },
  { pattern: /\bstill thinking about\b/i, label: "Still thinking about" },
  { pattern: /\bhaven'?t figured out\b/i, label: "Not figured out yet" },
  { pattern: /\bcan'?t stop thinking about\b/i, label: "Keeps circling" },
  { pattern: /\bon my mind\b/i, label: "On my mind" },
  { pattern: /\bnot sure what to do\b/i, label: "Unsure what to do" },
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

export function detectUnresolvedThreadUncached(
  transcript: string,
): UnresolvedThreadSignal | null {
  recordFunctionInvocation("detectUnresolvedThreadUncached");
  const text = transcript.trim();
  if (text.length < 12) return null;

  const anchorPhrases: string[] = [];
  const matchedLabels: string[] = [];
  let concernLabel: string | undefined;
  let title = "Open thread";

  for (const { pattern, label } of UNRESOLVED_PATTERNS) {
    const phrase = sentenceForMatch(text, pattern);
    if (!phrase) continue;
    if (!anchorPhrases.includes(phrase)) anchorPhrases.push(phrase);
    if (!matchedLabels.includes(label)) matchedLabels.push(label);
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
    matchedLabels,
  };
}
