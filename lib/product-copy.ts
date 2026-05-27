/** Shared product positioning — user-facing strings only. */

import { MEMORY_LANGUAGE } from "@/lib/memory-language";

export const WEDGE_POSITIONING = {
  notAiJournal: "Your words stay yours — speak privately; past phrases resurface when today matches.",
  wedge:
    "VoiceMemory brings back phrases you already spoke when today sounds like a past reflection.",
} as const;

export const PRODUCT_WEDGE_LINE = WEDGE_POSITIONING.wedge;

export const NOT_AI_JOURNAL_LINE = WEDGE_POSITIONING.notAiJournal;

/** Concrete resurfacing lines — prefer evidence over abstraction. */
export const WEDGE_RESURFACING = {
  forgottenPatterns: "Words you forgot you had already spoken.",
  wordsCameBack: MEMORY_LANGUAGE.thisCameBack,
  pastWordsMatch: MEMORY_LANGUAGE.wordsReturned,
  similarWordsBefore: "You used similar words before.",
  concernAgain: "This concern showed up again.",
  saidBeforeLeftAlone: MEMORY_LANGUAGE.youSaidBefore,
  ownVoicePattern: "Hearing your own voice makes the return harder to shrug off.",
  returnedAfterDays: (days: number) =>
    `This returned after ${days} day${days === 1 ? "" : "s"}.`,
} as const;

export const APP_EYEBROW = "Private voice reflections";
export const APP_TAGLINE = "Voice reflections that resurface in your own words.";
export const APP_LEAD =
  "Speak thoughts aloud. What you said before can return when it connects to today.";
export const APP_SUPPORT =
  "Record on this device. Sign in only if you want encrypted backup.";
export const APP_HONESTY =
  "Local-first. Not therapy, not a diagnosis, and not a score or streak.";
export const APP_DEVICE_LINE = "Speak for about a minute. Your words stay on this device.";

/** Homepage hero — understandable in ~5 seconds. */
export const HOMEPAGE_CLARITY = {
  stepSpeak: "Speak thoughts aloud",
  stepRemember: "Your past words stay on this device",
  stepReturn: "Repeated phrases from past reflections can surface before you speak again",
  ctaLine:
    "Record with your voice. After a few real reflections, wording you repeat across days can return in your own words.",
  exampleLabel: "Example",
  example:
    "Three weeks apart, you mentioned waiting for the same phone call.",
} as const;

export const APP_SUBTITLE = PRODUCT_WEDGE_LINE;
export const APP_DESCRIPTION_SHORT =
  "Private voice reflections that resurface forgotten moments from your own voice.";

export const SERVICE_DESCRIPTION = `${NOT_AI_JOURNAL_LINE} ${PRODUCT_WEDGE_LINE}`;

export const EXPORT_TRUST_FOOTER =
  "Exported from your device. Your own voice — not therapy or diagnosis.";

export const FOOTER_TRUST_LINE =
  "Your own voice, kept private — not therapy, not a diagnosis, not crisis support.";

/** @deprecated Use APP_EYEBROW */
export const POSITIONING_EYEBROW = APP_EYEBROW;
/** @deprecated Use APP_TAGLINE */
export const POSITIONING_TAGLINE = APP_TAGLINE;
/** @deprecated Use APP_LEAD */
export const POSITIONING_LEAD = APP_LEAD;
/** @deprecated Use APP_SUPPORT */
export const POSITIONING_SUPPORT = APP_SUPPORT;
/** @deprecated Use APP_HONESTY */
export const HONESTY_LINE = APP_HONESTY;
/** @deprecated Use APP_DEVICE_LINE */
export const DEVICE_PRIVACY_LINE = APP_DEVICE_LINE;

export const ONBOARDING_WHY_RETURN =
  "After a few real reflections, a phrase you used before can show up again when today sounds similar.";

export const ONBOARDING_HOME = {
  eyebrow: APP_EYEBROW,
  tagline: APP_TAGLINE,
  lead: APP_LEAD,
  support: APP_SUPPORT,
  honesty: APP_HONESTY,
  deviceLine: APP_DEVICE_LINE,
} as const;

export const ONBOARDING_ACTIVATION = {
  lead: "Record a short voice reflection. VoiceMemory keeps it on this device.",
  quietEarly:
    "The first day is often quiet. Return threads and timeline cards appear after a few real reflections—not from filler recordings.",
  whyReturn: ONBOARDING_WHY_RETURN,
  stepRecord: "Record one short reflection. VoiceMemory saves it on this device.",
  stepReturn: WEDGE_RESURFACING.wordsCameBack,
  stepBackup: "You can use it without backup. Sign in only if you want encrypted sync.",
  finish: "Go at your pace. Nothing to catch up on.",
} as const;

export const ONBOARDING_WELCOME = {
  description:
    "Record short voice reflections on this device. For early testers — no performance, no scoring.",
  memoryGrows: WEDGE_RESURFACING.similarWordsBefore,
} as const;

export const ACCOUNT_BACKUP = {
  signInLead: "Optional sign-in sends an encrypted copy — not plain text on our servers.",
  signedInLead: "Encrypted backup keeps a second copy. Your notes stay on this device first.",
  signInPrompt: "Sign in only if you want encrypted backup across devices.",
  lastBackedUp: (label: string) => `Last backed up ${label}.`,
  notYetBackedUp: "Not backed up yet.",
} as const;

export const ACCOUNT_STATUS_LABELS = {
  signed_out: "Not signed in",
  signed_in: "Signed in",
  syncing: "Backing up…",
  sync_error: "Backup issue",
} as const;
