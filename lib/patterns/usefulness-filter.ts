const GENERIC_PATTERNS = [
  /emotional state shifted/i,
  /your mood changed/i,
  /emotional trend/i,
  /insight generated/i,
  /pattern detected/i,
  /trend detected/i,
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
  /before|after|used to|lately|now|this time|for a while|absent|named it|got quieter|came up before|sound different|sound very different|not appeared for a while|came back today|quieter than last time|last talked about|days ago|sundays|mondays|last monday|last month|end of the week|late in the week|lighter than|heavier lately|feels similar|this month sounds|tends to return|couple of weeks|read differently|reads differently|first time this topic|sound different from this entry|before things got quieter|older reflection|quiet stretch|had not named|had not started naming|less tension|more directly|loop came back|more weight|more vaguely|carry more pressure|named this more directly|concern has been absent|you changed|you sound different here|more settled than usual|circle this topic longer|returned to this more quickly|more direct than your usual|more than you usually leave|take longer before this comes back|after busy weeks|gap between these entries|stayed calmer for longer|weekly rhythm|took longer than usual|pace between entries|shows up late|earlier version of this same loop|first calmer entry|version of yourself|spoke about this before|months ago|beginning to connect|more familiar over time|more continuity|starting to relate|older reflections|entries read differently|archive feels|reflections are starting|you came back|left this unresolved|sounds like a continuation|stopped here before|returned to this differently|thread changed quietly/i,
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
