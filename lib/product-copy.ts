/** Shared product positioning — user-facing strings only. */

export const WEDGE_POSITIONING = {
  notAiJournal: "VoiceMemory is not an AI journal.",
  wedge: "VoiceMemory resurfaces forgotten emotional patterns from your own voice.",
} as const;

export const PRODUCT_WEDGE_LINE = WEDGE_POSITIONING.wedge;

export const NOT_AI_JOURNAL_LINE = WEDGE_POSITIONING.notAiJournal;

/** Concrete resurfacing lines — prefer evidence over abstraction. */
export const WEDGE_RESURFACING = {
  forgottenPatterns: "Patterns you forgot you were repeating.",
  wordsCameBack: "Your own words came back.",
  pastWordsMatch: "Your own words came back when they match today.",
  similarWordsBefore: "You used similar words before.",
  concernAgain: "This concern showed up again.",
  saidBeforeLeftAlone: "You said this before, then left it alone.",
  ownVoicePattern: "Your voice makes the pattern harder to ignore.",
  returnedAfterDays: (days: number) =>
    `This returned after ${days} day${days === 1 ? "" : "s"}.`,
} as const;

export const APP_EYEBROW = "Private voice reflections";
export const APP_TAGLINE = "Record a short reflection. Keep it on this device.";
export const APP_LEAD =
  "Record one short reflection. VoiceMemory saves it here until you export or delete it.";
export const APP_SUPPORT = `${WEDGE_RESURFACING.wordsCameBack} Sign in only if you want encrypted backup.`;
export const APP_HONESTY =
  "Local-first on this device. Not therapy, not a diagnosis, and not a score or streak.";
export const APP_DEVICE_LINE = "Speak for about a minute. Your words stay on this device.";

export const APP_SUBTITLE = PRODUCT_WEDGE_LINE;
export const APP_DESCRIPTION_SHORT =
  "Private voice reflections that resurface forgotten patterns from your own voice.";

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
  "The value appears when today connects to something you said before.";

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
  quietEarly: "The first day may feel quiet. That is normal.",
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
