export interface ResurfacingAmbiguityAssessment {
  ambiguityScore: number;
  sarcasmSignal: string | null;
  vaguenessSignal: string | null;
  cautiousWordingRequired: boolean;
  recommendedCopyPrefix: string | null;
}

const SARCASM_RE =
  /\b(lol|lmao|yeah right|sure sure|whatever|as if|totally fine|totally|obviously not)\b/i;
const JOKE_RE = /\b(joking|kidding|not really|just kidding)\b/i;
const UNCERTAINTY_RE =
  /\b(i don'?t know|maybe|kind of|sort of|not sure|i guess|probably|might)\b/i;
const VAGUE_PRONOUN_RE = /\b(it|this|that|they|them)\b/i;
const FLAT_RE =
  /^(ok|okay|fine|meh|idk|nothing much|same as usual)\.?$/i;
const OVERCONFIDENT_BANNED_RE =
  /\b(you are|you always|this means|clearly|definitely|you still|you need)\b/i;

export function assessResurfacingAmbiguity(
  text: string,
  options?: { missingTranscript?: boolean; vagueMoodField?: boolean },
): ResurfacingAmbiguityAssessment {
  const trimmed = text.trim();
  let score = 0;
  let sarcasmSignal: string | null = null;
  let vaguenessSignal: string | null = null;

  if (options?.missingTranscript) {
    score += 35;
    vaguenessSignal = "missing transcript";
  }
  if (options?.vagueMoodField) {
    score += 18;
    vaguenessSignal = vaguenessSignal ?? "vague mood or reflection";
  }
  if (!trimmed) {
    return {
      ambiguityScore: 90,
      sarcasmSignal: null,
      vaguenessSignal: "empty text",
      cautiousWordingRequired: true,
      recommendedCopyPrefix: "This is only a loose match…",
    };
  }

  if (SARCASM_RE.test(trimmed) || JOKE_RE.test(trimmed)) {
    score += 42;
    sarcasmSignal = "sarcasm or joke markers";
  }
  if (UNCERTAINTY_RE.test(trimmed)) {
    score += 22;
    vaguenessSignal = vaguenessSignal ?? "uncertain wording";
  }
  if (trimmed.length < 18 && VAGUE_PRONOUN_RE.test(trimmed)) {
    score += 28;
    vaguenessSignal = vaguenessSignal ?? "short text with vague pronouns";
  }
  if (FLAT_RE.test(trimmed)) {
    score += 40;
    vaguenessSignal = vaguenessSignal ?? "emotionally flat note";
  }
  if (trimmed.split(/\s+/).length < 6) {
    score += 12;
  }

  const cautiousWordingRequired = score >= 30;
  const recommendedCopyPrefix = cautiousWordingRequired
    ? score >= 55
      ? "This is only a loose match…"
      : score >= 38
        ? "This may be related…"
        : "This might connect…"
    : null;

  return {
    ambiguityScore: Math.min(100, score),
    sarcasmSignal,
    vaguenessSignal,
    cautiousWordingRequired,
    recommendedCopyPrefix,
  };
}

export function containsOverconfidentResurfacingCopy(text: string): boolean {
  return OVERCONFIDENT_BANNED_RE.test(text);
}

export function sanitizeResurfacingCopyForAmbiguity(
  text: string,
  cautious: boolean,
): string {
  if (!cautious) return text;
  let out = text;
  for (const phrase of [
    "you are",
    "you always",
    "this means",
    "clearly",
    "definitely",
    "you still",
    "you need",
  ]) {
    const re = new RegExp(`\\b${phrase}\\b`, "gi");
    out = out.replace(re, "this might");
  }
  return out;
}
