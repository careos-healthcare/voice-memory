/** Plain-language onboarding copy — every line should pass the “normal person” test. */

export const ONBOARDING_WHY_RETURN =
  "The value appears when today connects to something you said before.";

export const ONBOARDING_HOME = {
  eyebrow: "Private voice reflections",
  tagline: "Record a short reflection. Keep it on this device.",
  lead: "Record one short reflection. VoiceMemory saves it here until you export or delete it.",
  support:
    "When similar words, moods, or concerns show up later, an older entry may gently return. Sign in only if you want encrypted backup.",
  honesty:
    "Local-first on this device. Not therapy, not a diagnosis, and not a score or streak.",
  deviceLine: "Speak for about a minute. Your words stay on this device.",
} as const;

export const ONBOARDING_RECORDER = {
  idle: "Tap to speak. Up to about a minute.",
  processing: "Saving your words on this device…",
  calm: "Talk naturally. You do not need a neat ending.",
} as const;

export const ONBOARDING_MEMORY = {
  title: "Your reflections",
  empty: "Nothing here yet. One short voice reflection is enough to start.",
  loading: "One moment…",
} as const;

export const ONBOARDING_ARCHIVE = {
  permanenceNeverTrapped: "Your notes are not locked in here.",
  takeWithYou: "You can download everything anytime.",
  previewRestore: "Look inside a backup file before you bring it back.",
} as const;

export const ONBOARDING_ACCOUNT = {
  backupLead: "Optional sign-in sends an encrypted copy — not plain text on our servers.",
  continuitySignedIn: "Your notes on this phone can be backed up when you choose.",
} as const;

export const ONBOARDING_ACTIVATION = {
  lead: "Record a short voice reflection. VoiceMemory keeps it on this device.",
  quietEarly: "The first day may feel quiet. That is normal.",
  whyReturn: ONBOARDING_WHY_RETURN,
  stepRecord: "Record one short reflection. VoiceMemory saves it on this device.",
  stepReturn:
    "When similar words, moods, or concerns appear later, it can gently bring the old reflection back.",
  stepBackup: "You can use it without backup. Sign in only if you want encrypted sync.",
  finish: "Go at your pace. Nothing to catch up on.",
} as const;

export const ONBOARDING_WELCOME = {
  description:
    "Record short voice reflections on this device. For early testers — no performance, no scoring.",
  memoryGrows:
    "Older reflections may return when something you say today connects to words you used before.",
} as const;
