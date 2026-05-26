import type { ThoughtPattern, ThoughtPatternKind } from "@/types/clarity";

const MIN_QUOTE_LEN = 14;
const MAX_QUOTE_LEN = 120;

function cleanQuote(raw: string): string {
  const compact = raw.replace(/\s+/g, " ").trim();
  if (compact.length <= MAX_QUOTE_LEN) return compact;
  return `${compact.slice(0, MAX_QUOTE_LEN - 1)}…`;
}

function pushPattern(
  out: ThoughtPattern[],
  kind: ThoughtPatternKind,
  match: RegExpMatchArray,
  transcript: string,
): void {
  const fragment = (match[1] ?? match[0]).trim();
  if (fragment.length < MIN_QUOTE_LEN) return;
  const quote = cleanQuote(fragment);
  if (out.some((row) => row.quote === quote)) return;
  if (!transcript.toLowerCase().includes(quote.slice(0, 12).toLowerCase())) return;
  out.push({ kind, quote });
}

/** Extract user-owned phrases only — no labels, diagnoses, or advice. */
export function extractThoughtPatterns(transcript: string): ThoughtPattern[] {
  const text = transcript.trim();
  if (text.length < 24) return [];

  const patterns: ThoughtPattern[] = [];

  const rules: Array<{ kind: ThoughtPatternKind; re: RegExp }> = [
    {
      kind: "assumption",
      re: /\b(?:i assumed|i'?m assuming|i thought)([^.!?]{8,140})/gi,
    },
    {
      kind: "avoided_speech",
      re: /\b(?:i avoided saying|i didn'?t say|i wanted to say but)([^.!?]{8,140})/gi,
    },
    {
      kind: "repeated_concern",
      re: /\b(?:i keep (?:thinking|coming back to)|keeps coming back to)([^.!?]{8,140})/gi,
    },
    {
      kind: "desired_response",
      re: /\b(?:i wanted (?:them|him|her|you) to|i needed (?:them|him|her|you) to)([^.!?]{8,140})/gi,
    },
    {
      kind: "unresolved_question",
      re: /\b(?:i don'?t know if|why did (?:they|he|she)|what did (?:they|he|she) mean)([^.!?]{8,140})/gi,
    },
    {
      kind: "emotional_trigger",
      re: /\b(?:when (?:they|he|she) said|it hurt when)([^.!?]{8,140})/gi,
    },
  ];

  for (const rule of rules) {
    const re = new RegExp(rule.re.source, rule.re.flags);
    let match: RegExpExecArray | null;
    while ((match = re.exec(text)) !== null && patterns.length < 8) {
      pushPattern(patterns, rule.kind, match, text);
    }
  }

  return patterns
    .filter((row) => row.quote.length >= MIN_QUOTE_LEN)
    .slice(0, 6);
}

export function thoughtPatternsStrongEnough(patterns: ThoughtPattern[]): boolean {
  return patterns.length >= 1 && patterns.some((row) => row.quote.length >= 20);
}

export function displayThoughtPatterns(patterns: ThoughtPattern[]): ThoughtPattern[] {
  if (!thoughtPatternsStrongEnough(patterns)) return [];
  return patterns.slice(0, 3);
}
