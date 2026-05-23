const GENERIC_PATTERNS = [
  /emotional state shifted/i,
  /your mood changed/i,
  /emotional trend/i,
  /insight generated/i,
  /pattern detected/i,
  /\banalysis\b/i,
  /\bsummary\b/i,
  /this changed over time/i,
  /shifted across \d+ reflections/i,
  /dominant emotion/i,
  /not therapy/i,
  /not a diagnosis/i,
  /computed locally/i,
  /pattern observation/i,
  /\bconfidence\b/i,
  /\bsignal\b/i,
  /emotional evolution/i,
];

const ORIENTATION_SIGNALS = [
  /stopped (saying|using|mentioning)/i,
  /first (time|calmer|direct)/i,
  /less (intense|charged|tension|hedged|vague)/i,
  /more (direct|clear|calm|forward)/i,
  /came (back|up differently)/i,
  /faded|disappeared|returned|resolved|recovery|peaked/i,
  /before|after|used to|lately|now|this time|for a while|absent|named it|got quieter|came up before|sound different|not appeared for a while|came back today|quieter than last time|last talked about|days ago/i,
  /\d+\/10/,
];

export const USEFULNESS_MIN_CONFIDENCE = 58;

/** Does this text help someone orient over time — not just label a mood? */
export function helpsOrient(text: string, confidence: number): boolean {
  if (confidence < USEFULNESS_MIN_CONFIDENCE) return false;
  if (GENERIC_PATTERNS.some((re) => re.test(text))) return false;
  if (text.trim().length < 18) return false;
  return ORIENTATION_SIGNALS.some((re) => re.test(text));
}

export function filterOrienting<T extends { confidence: number }>(
  items: T[],
  textOf: (item: T) => string,
): T[] {
  return items.filter((item) => helpsOrient(textOf(item), item.confidence));
}

export function pickStrongest<T extends { confidence: number }>(
  items: T[],
  limit: number,
): T[] {
  return [...items].sort((a, b) => b.confidence - a.confidence).slice(0, limit);
}
