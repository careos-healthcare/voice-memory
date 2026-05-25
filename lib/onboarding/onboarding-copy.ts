/** Plain-language onboarding copy — every line should pass the “normal person” test. */

export const ONBOARDING_HOME = {
  eyebrow: "Private memory intelligence",
  tagline: "Private memory intelligence from your voice reflections",
  lead: "Talk naturally. VoiceMemory notices recurring patterns over time.",
  support:
    "A private intelligence layer for your thoughts, moods, people, goals, and recurring concerns.",
  honesty:
    "Local-first on this device. Reflective mirror only — not therapy, not a diagnosis.",
  deviceLine: "Speak for a minute. Your words stay on this phone.",
} as const;

export const ONBOARDING_RECORDER = {
  idle: "Tap to speak. Up to about a minute.",
  processing: "Saving your words on this device…",
  calm: "Talk naturally. You do not need a neat ending.",
} as const;

export const ONBOARDING_MEMORY = {
  title: "Your memory layer",
  empty: "Nothing here yet. One voice reflection is enough to start noticing patterns.",
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
  lead: "Private memory intelligence — not a diary app with folders.",
  quietEarly: "The first day may feel quiet. That is normal.",
  stepRecord: "Day 1: talk naturally, speak, your reflection stays here.",
  stepReturn: "Later: VoiceMemory may surface an older moment when it still fits.",
  stepGrow: "Over time: recurring patterns in your thoughts, moods, and concerns.",
  finish: "Go at your pace. Nothing to catch up on.",
} as const;

export const ONBOARDING_WELCOME = {
  description:
    "Private memory intelligence from your voice. For early testers who want to try it honestly — not to perform or put on a show.",
  memoryGrows:
    "Patterns emerge slowly. Early days can feel empty. That is fine — return when something matters.",
} as const;
