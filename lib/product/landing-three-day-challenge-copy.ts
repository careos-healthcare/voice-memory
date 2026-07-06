/** Public landing — 3-day proof challenge positioning (web homepage). */

export const LANDING_3_DAY_CHALLENGE = {
  eyebrow: "3-day proof challenge",
  hero: "See what keeps coming back.",
  subhero:
    "Record one private moment a day for 3 days. ArchiveMe compares your saved moments and shows what returned, changed, softened, or went quiet.",
  chatGptDifferentiation:
    "ChatGPT helps you think today. ArchiveMe shows what keeps repeating across your life.",
  primaryCta: "Start the 3-day proof challenge",
  secondaryCta: "How it works",
  secondaryHref: "/how-it-works",
  recorderIntro:
    "Day 1 starts here. One private moment — then come back tomorrow.",
  steps: [
    {
      title: "Record one moment",
      body: "Save one private reflection today — in your own words, on this device.",
    },
    {
      title: "Come back tomorrow",
      body: "A single moment is not the story. ArchiveMe compares what you save across days.",
    },
    {
      title: "See what returned",
      body: "After a few saves, you may see what kept returning, changed, softened, or went quiet.",
    },
  ] as const,
  proSection: {
    headline: "Keep the longer story with Pro",
    paidReason: "Pro keeps the longer story",
    bullets: [
      "Longer archive history",
      "Private monthly reports",
      "Evidence over time",
      "Pattern correction history",
      "Backup and preservation (planned Pro area — not live today)",
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
} as const;

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
  const { steps, proSection, trust } = LANDING_3_DAY_CHALLENGE;
  return [
    LANDING_3_DAY_CHALLENGE.eyebrow,
    LANDING_3_DAY_CHALLENGE.hero,
    LANDING_3_DAY_CHALLENGE.subhero,
    LANDING_3_DAY_CHALLENGE.chatGptDifferentiation,
    LANDING_3_DAY_CHALLENGE.primaryCta,
    LANDING_3_DAY_CHALLENGE.secondaryCta,
    LANDING_3_DAY_CHALLENGE.recorderIntro,
    ...steps.flatMap((step) => [step.title, step.body]),
    proSection.headline,
    proSection.paidReason,
    ...proSection.bullets,
    trust.headline,
    ...trust.bullets,
  ];
}
