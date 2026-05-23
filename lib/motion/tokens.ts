/** Calm motion tokens — intimate, slow, non-gamified. */
export const MOTION = {
  ease: [0.22, 1, 0.36, 1] as const,
  easeOut: "easeOut" as const,
  duration: {
    fade: 0.85,
    note: 1.05,
    page: 0.95,
    slow: 1.3,
    presence: 0.75,
  },
  offset: {
    subtle: 5,
    note: 8,
    page: 10,
  },
  stagger: {
    note: 0.14,
    list: 0.1,
    thenVsNow: 0.38,
  },
  delay: {
    continuation: 0.45,
    resurfacing: 0.3,
    quiet: 0.55,
    hero: 0.12,
  },
} as const;

export type NoteMotionTone = "default" | "resurfacing" | "quiet" | "continuation";

export function noteDelayForTone(tone: NoteMotionTone, index: number): number {
  switch (tone) {
    case "continuation":
      return MOTION.delay.continuation;
    case "quiet":
      return MOTION.delay.quiet;
    case "resurfacing":
      return MOTION.delay.resurfacing + index * MOTION.stagger.note;
    default:
      return index * MOTION.stagger.note;
  }
}
