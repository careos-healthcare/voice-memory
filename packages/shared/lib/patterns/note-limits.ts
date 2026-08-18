/** Max items in quiet UI — fourth only when evidence is strong. */
export const MAX_MEMORY_NOTES = 4;
export const MAX_LANDMARKS = 4;
export const MAX_THEN_VS_NOW = 2;
export const MAX_ENTRY_CALLBACKS = 2;

/** Minimum confidence to show a 4th note, 2nd comparison, or extra landmark. */
export const STRONG_EXTRA_CONFIDENCE = 72;
export const STRONG_THEN_VS_NOW_SECOND = 72;

export function applyStrongExtraLimit<T extends { confidence: number }>(
  items: T[],
  max: number,
): T[] {
  if (items.length === 0) return [];
  const sorted = [...items].sort((a, b) => b.confidence - a.confidence);
  const base = sorted.slice(0, Math.min(max - 1, sorted.length));
  if (sorted.length >= max && sorted[max - 1].confidence >= STRONG_EXTRA_CONFIDENCE) {
    return sorted.slice(0, max);
  }
  return base;
}
