import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";

/** Product-clarity pass — homepage, discover, archive differentiation (restrained). */

export const PRODUCT_HERO = {
  eyebrow: LANDING_3_DAY_CHALLENGE.subheadline,
  promise: LANDING_3_DAY_CHALLENGE.hero,
  archiveLead: LANDING_3_DAY_CHALLENGE.subhero,
  support:
    "Speak on this device. When the same concern returns across weeks, you may see it named — not scored, not coached.",
  honesty: "Local-first. Not therapy, not a diagnosis, and not a score or streak.",
  deviceLine: "Your archive stays on this device unless you choose encrypted backup.",
} as const;

export const EVOLVING_VIEW_INTRO =
  "ArchiveMe does not try to define you from one reflection. It builds a working view from repeated evidence." as const;

export const HOMEPAGE_ARCHIVE_DIFFERENTIATION = {
  title: "What ArchiveMe tracks",
  lineA: "ArchiveMe remembers what you keep saying over weeks and months.",
  lineB: "ArchiveMe shows the timeline behind the pattern.",
  archiveGrowth:
    "A single moment answers today. ArchiveMe tracks what keeps returning.",
  eachReflection:
    "Each moment gives ArchiveMe more evidence about what keeps returning.",
  complement:
    "Many people capture moments elsewhere — ArchiveMe is for what your own words keep returning to.",
  chatGptDifferentiation: LANDING_3_DAY_CHALLENGE.chatGptDifferentiation,
} as const;

/** @deprecated Use HOMEPAGE_ARCHIVE_DIFFERENTIATION */
export const HOMEPAGE_CHATGPT = HOMEPAGE_ARCHIVE_DIFFERENTIATION;

export const PRODUCT_DEMO_STORY = {
  label: "Example only",
  body: "You said three times that criticism means you're failing. This may be why manager feedback keeps spiralling.",
  disclaimer: "Illustration — not a claim about you until your archive supports it.",
} as const;

export const PATTERN_ACTIVATION = {
  targetReflections: 5,
  progressTemplate: (current: number, target: number) =>
    `${Math.min(current, target)}/${target} reflections toward your first belief.`,
  readyLead: "You may have enough history for a first belief.",
  discoverCta: "See what changed",
  blindSpotsCta: "Open blind spot review",
} as const;

export const RETURNING_HOME = {
  discoverHeadline: "What your archive currently believes",
  discoverFallbackTitle: "Building your baseline",
  discoverFallbackBody:
    "Visit again after a few more reflections — theory shifts and evidence will compare against this visit.",
} as const;

export { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";
