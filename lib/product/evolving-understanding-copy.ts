/** Evolving understanding — archive view grows with evidence, not one-off insights. */

export const EVOLVING_UNDERSTANDING_INTRO = {
  headline: "A working view from repeated evidence",
  body:
    "ArchiveMe does not try to define you from one moment. It builds a working view from repeated evidence.",
} as const;

export const EVOLVING_FIRST_WORKING_THEORY = {
  eyebrow: "First working theory",
  notVerdict:
    "This is not a verdict. It is the first theory your archive can support.",
  mayChange:
    "As you add more moments, this may strengthen, weaken, or disappear.",
  archiveView:
    "ArchiveMe is starting to build an evidence-based view of what keeps repeating.",
} as const;

export const WHAT_HAPPENS_NEXT = {
  title: "What happens next?",
  bullets: [
    "New moments can strengthen this theory.",
    "Contradicting evidence can weaken it.",
    "Patterns can disappear when your behavior changes.",
    "Discover shows what changed since your last visit.",
  ],
  cta: "Check what changes",
  ctaHref: "/discover",
} as const;

export const EVOLVING_VIEW_CARD = {
  headline: "Your archive has started forming a view.",
  subline: "Each new moment can change that view.",
  totalTheories: "Theories tracked",
  underReview: "Under review",
  strengthening: "Strengthening",
  weakeningResolved: "Weakening or resolved",
  lastUpdated: "Last updated",
} as const;

export const POST_SAVE_EVOLVING_NOTES = [
  "Your archive view may change as new evidence arrives.",
  "This moment has been added to the evidence.",
  "ArchiveMe will compare this against what you have said before.",
] as const;

/** Show at most one evolving note — sparingly after compare is possible. */
export function pickPostSaveEvolvingNote(reflectionCount: number): string | null {
  if (reflectionCount < 2) return null;
  if (reflectionCount % 3 !== 0) return null;
  const index = Math.floor(reflectionCount / 3) % POST_SAVE_EVOLVING_NOTES.length;
  return POST_SAVE_EVOLVING_NOTES[index] ?? null;
}
