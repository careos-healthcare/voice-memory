/** Shared motion tokens for archive polish (respects reduced motion in components). */

export const ARCHIVE_FADE_IN = {
  initial: { opacity: 0, y: 10 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.38, ease: [0.22, 1, 0.36, 1] as const },
} as const;

export const ARCHIVE_CARD_FADE = {
  initial: { opacity: 0, y: 14 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.42, ease: [0.22, 1, 0.36, 1] as const },
} as const;

export const ARCHIVE_MOVEMENT_FADE = {
  initial: { opacity: 0, y: 8, scale: 0.98 },
  animate: { opacity: 1, y: 0, scale: 1 },
  transition: { duration: 0.45, ease: [0.22, 1, 0.36, 1] as const },
} as const;

export const ARCHIVE_CONFIDENCE_PULSE = {
  initial: { opacity: 0.6, scale: 0.92 },
  animate: { opacity: 1, scale: 1 },
  transition: { duration: 0.5, ease: [0.22, 1, 0.36, 1] as const },
} as const;

export function archiveStaggerDelay(index: number, baseMs = 0.06): number {
  return index * baseMs;
}
