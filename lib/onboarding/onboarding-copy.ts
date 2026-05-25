/** Plain-language onboarding copy — every line should pass the “normal person” test. */

export {
  ONBOARDING_WHY_RETURN,
  ONBOARDING_HOME,
  ONBOARDING_ACTIVATION,
  ONBOARDING_WELCOME,
} from "@/lib/product-copy";

export const ONBOARDING_RECORDER = {
  idle: "Tap to speak. Up to about a minute.",
  processing: "Saving your words on this device…",
  calm: "Talk naturally. You do not need a neat ending.",
} as const;

export const ONBOARDING_MEMORY = {
  title: "Your reflections",
  empty: "Nothing here yet. One short voice reflection is enough to start.",
  loading: "One moment…",
  wedge: "Patterns you forgot you were repeating may show up here as your archive grows.",
} as const;

export const ONBOARDING_ARCHIVE = {
  permanenceNeverTrapped: "Your notes are not locked in here.",
  takeWithYou: "You can download everything anytime.",
  previewRestore: "Look inside a backup file before you bring it back.",
} as const;

export const ONBOARDING_ACCOUNT = {
  backupLead: "Optional sign-in sends an encrypted copy — not plain text on our servers.",
  continuitySignedIn: "Encrypted backup keeps a second copy. Your notes stay on this device first.",
} as const;
