/** Public landing — ArchiveMe timeline positioning (web homepage). */

export const LANDING_3_DAY_CHALLENGE = {
  subheadline: "No daily journal required.",
  hero: "See what keeps returning",
  subhero:
    "Save small moments when something stands out. ArchiveMe turns them into a private timeline of what appeared, what returned, what you corrected, and what still matters now.",
  chatGptDifferentiation:
    "ChatGPT can answer a conversation. ArchiveMe shows the timeline behind the pattern.",
  primaryCta: "Save your first moment",
  secondaryCta: "How it works",
  secondaryHref: "/how-it-works",
  recorderIntro: "Save one small moment when something stands out.",
  steps: [
    {
      title: "Save one small moment",
      body: "When something stands out, save it in your own words on this device.",
    },
    {
      title: "Come back when something stands out",
      body: "No daily streak required. Return when another moment matters.",
    },
    {
      title: "See what returned",
      body: "After a few saves, see what appeared, returned, or went quiet.",
    },
    {
      title: "Correct what is not relevant",
      body: "Mark what does not fit. Your timeline stays yours.",
    },
    {
      title: "Keep the full timeline with Pro",
      body: "Free shows the first proof. Pro keeps the full timeline as it grows.",
    },
  ] as const,
  proSection: {
    headline: "Keep the full timeline with Pro",
    paidReason: "Pro keeps the full timeline as it grows.",
    freePositioning: "Free shows the first proof. Pro keeps the full timeline as it grows.",
    bullets: [
      "Full pattern timeline",
      "Correction history",
      "Changing current weight",
      "Longer evidence trail",
      "Monthly private report",
      "Backup and continuity",
    ] as const,
  },
  trust: {
    headline: "Private by default",
    bullets: [
      "Private by default",
      "Based on moments you save",
      "Not therapy or medical advice",
      "You control what you keep",
    ] as const,
  },
  pricing: {
    pageEyebrow: "No daily journal required.",
    pageTitle: "Plans for your archive",
    pageLead:
      "Free shows the first proof. Pro keeps the full timeline as it grows.",
  },
} as const;

/** @deprecated Use subheadline — kept for PRODUCT_HERO.eyebrow wiring */
export const LANDING_EYEBROW = LANDING_3_DAY_CHALLENGE.subheadline;

/** Banned on public landing — live claims or clinical framing. */
export const LANDING_3_DAY_BANNED_PHRASES = [
  "therapy",
  "diagnosis",
  "medical treatment",
  "cloud backup included",
  "sync is active",
  "guaranteed transformation",
  "universal mental health",
  "more ai",
  "smarter chat",
] as const;

export function landingVisibleStrings(): string[] {
  const { steps, proSection, trust, pricing } = LANDING_3_DAY_CHALLENGE;
  return [
    LANDING_3_DAY_CHALLENGE.subheadline,
    LANDING_3_DAY_CHALLENGE.hero,
    LANDING_3_DAY_CHALLENGE.subhero,
    LANDING_3_DAY_CHALLENGE.chatGptDifferentiation,
    LANDING_3_DAY_CHALLENGE.primaryCta,
    LANDING_3_DAY_CHALLENGE.secondaryCta,
    LANDING_3_DAY_CHALLENGE.recorderIntro,
    ...steps.flatMap((step) => [step.title, step.body]),
    proSection.headline,
    proSection.paidReason,
    proSection.freePositioning,
    ...proSection.bullets,
    trust.headline,
    ...trust.bullets,
    pricing.pageEyebrow,
    pricing.pageTitle,
    pricing.pageLead,
  ];
}
