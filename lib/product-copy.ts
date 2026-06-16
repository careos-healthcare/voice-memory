/** Shared product positioning — user-facing strings only. */

import { MEMORY_LANGUAGE } from "@/lib/memory-language";
import { RECOGNITION_COPY } from "@/lib/product/recognition-copy";

export const WEDGE_POSITIONING = {
  notAiJournal: RECOGNITION_COPY.notAiJournal,
  wedge: RECOGNITION_COPY.wedge,
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

import { VOICEMEMORY_ARCHIVE_POSITIONING } from "@/lib/product/archive-positioning";
import {
  HOMEPAGE_ARCHIVE_DIFFERENTIATION,
  HOMEPAGE_CHATGPT,
  PRODUCT_DEMO_STORY,
  PRODUCT_HERO,
} from "@/lib/product/product-clarity-copy";

export { VOICEMEMORY_ARCHIVE_POSITIONING } from "@/lib/product/archive-positioning";

export const APP_EYEBROW = PRODUCT_HERO.eyebrow;
export const APP_TAGLINE = PRODUCT_HERO.promise;
export const APP_LEAD = PRODUCT_HERO.archiveLead;
export const APP_SUPPORT = PRODUCT_HERO.support;
export const APP_HONESTY = PRODUCT_HERO.honesty;
export const APP_DEVICE_LINE = PRODUCT_HERO.deviceLine;

/** Homepage hero — understandable in ~5 seconds. */
export const HOMEPAGE_CLARITY = {
  stepSpeak: RECOGNITION_COPY.homepageSpeak,
  stepRemember: RECOGNITION_COPY.homepageRemember,
  stepReturn: RECOGNITION_COPY.homepageReturn,
  ctaLine: RECOGNITION_COPY.homepageCta,
  exampleLabel: PRODUCT_DEMO_STORY.label,
  example: PRODUCT_DEMO_STORY.body,
  archiveDifferentiation: HOMEPAGE_ARCHIVE_DIFFERENTIATION,
  /** @deprecated Use archiveDifferentiation */
  chatgpt: HOMEPAGE_CHATGPT,
  lead: PRODUCT_HERO.archiveLead,
  /** @deprecated Use lead */
  objection: PRODUCT_HERO.archiveLead,
} as const;

export {
  HOMEPAGE_ARCHIVE_DIFFERENTIATION,
  HOMEPAGE_CHATGPT,
  PRODUCT_DEMO_STORY,
  PRODUCT_HERO,
};

export const APP_SUBTITLE = RECOGNITION_COPY.appSubtitle;
export const APP_DESCRIPTION_SHORT =
  "Private voice reflections that return in your own words.";

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

export const ONBOARDING_WHY_RETURN = "A phrase you said before can show up again.";

export const ONBOARDING_HOME = {
  eyebrow: APP_EYEBROW,
  tagline: APP_TAGLINE,
  lead: APP_LEAD,
  support: APP_SUPPORT,
  honesty: APP_HONESTY,
  deviceLine: APP_DEVICE_LINE,
} as const;

/** @deprecated UI uses ARCHIVE_ONBOARDING_SCREENS — stubs for legacy imports only. */
export const ONBOARDING_ACTIVATION = {
  lead: "Your archive keeps track of what keeps repeating.",
  evolvingView: "",
  quietEarly: "",
  whyReturn: ONBOARDING_WHY_RETURN,
  stepRecord: "Every reflection becomes evidence.",
  stepReturn: "Those beliefs strengthen, weaken, or disappear.",
  stepBackup: "",
  finish: "Record your first reflection.",
} as const;

export const ONBOARDING_WELCOME = {
  description: "Speak privately on this device. No performance, no scoring.",
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
