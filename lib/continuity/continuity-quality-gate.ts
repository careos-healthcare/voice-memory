/** Fallback when continuity would otherwise surface test/noise content. */
export const CONTINUITY_FALLBACK_LINE = "Say the next thing before it hardens.";

const NUMERIC_RUN_RE = /(?:\b\d+\b[,.]?\s*){4,}/;
const COUNTING_RE = /\b(one|two|three|four|five|six|seven|eight|nine|ten)\b[,.]?\s+(one|two|three|four|five|six|seven|eight|nine|ten)\b/i;
const DIGIT_SEQUENCE_RE = /\b1\s*[,.\s]\s*2\s*[,.\s]\s*3\b/;
const TEST_PHRASE_RE =
  /\b(just a test|this is a test|this is only a test|test test|testing one two|lorem ipsum)\b/i;
const MEANINGLESS_SHORT_RE = /^[\d\s,.!?-]{1,24}$/;
const FILLER_REPEAT_RE = /\b(\w{2,})(?:\s+\1\b){2,}/i;

function normalized(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

/** Raw transcript unsuitable for continuity or return threads. */
export function isLowQualityTranscript(text: string): boolean {
  const t = normalized(text);
  if (!t) return true;
  if (t.length < 12) return true;
  if (MEANINGLESS_SHORT_RE.test(t)) return true;
  if (NUMERIC_RUN_RE.test(t)) return true;
  if (COUNTING_RE.test(t)) return true;
  if (DIGIT_SEQUENCE_RE.test(t)) return true;
  if (TEST_PHRASE_RE.test(t)) return true;
  if (FILLER_REPEAT_RE.test(t)) return true;
  const words = t.split(/\s+/).filter(Boolean);
  if (words.length < 3) return true;
  const digitChars = (t.match(/\d/g) ?? []).length;
  if (digitChars / t.length > 0.35) return true;
  return false;
}

/** Quote or line shown above the mic or on thread cards. */
export function isLowQualityContinuityQuote(text: string): boolean {
  const t = normalized(text.replace(/^["']|["']$/g, ""));
  if (!t) return true;
  if (isLowQualityTranscript(t)) return true;
  if (NUMERIC_RUN_RE.test(t) || DIGIT_SEQUENCE_RE.test(t)) return true;
  return false;
}

export function gateContinuityQuote(quote: string): string | null {
  const trimmed = quote.trim();
  if (!trimmed || isLowQualityContinuityQuote(trimmed)) return null;
  return trimmed;
}

export function gateContinuityLine(line: string | null | undefined): string | null {
  if (!line?.trim()) return null;
  const trimmed = line.trim();
  if (isLowQualityContinuityQuote(trimmed)) return null;
  if (/\b\d+\s*[,.\s]\s*\d+\s*[,.\s]\s*\d+/.test(trimmed)) return null;
  return trimmed;
}

/** Pre-mic or homepage line — never surfaces test/number noise. */
export function resolveContinuityLine(line: string | null | undefined): string | null {
  const gated = gateContinuityLine(line);
  if (gated) return gated;
  return null;
}

/** When a line slot exists but content is weak, use calm fallback. */
export function resolveContinuityLineOrFallback(
  line: string | null | undefined,
  options?: { allowFallback?: boolean },
): string | null {
  const gated = resolveContinuityLine(line);
  if (gated) return gated;
  if (options?.allowFallback === false) return null;
  return CONTINUITY_FALLBACK_LINE;
}
