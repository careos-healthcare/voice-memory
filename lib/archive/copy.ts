import { ONBOARDING_ARCHIVE } from "@/lib/onboarding/onboarding-copy";

/** User-facing archive permanence copy. */
export const ARCHIVE_PERMANENCE_COPY = {
  neverTrapped: ONBOARDING_ARCHIVE.permanenceNeverTrapped,
  takeWithYou: ONBOARDING_ARCHIVE.takeWithYou,
  previewBeforeRestore: ONBOARDING_ARCHIVE.previewRestore,
  replaceWarning:
    "Replace will remove all moments and audio on this device, then restore from this archive.",
  mergeNote: "Merge keeps what you have and adds or updates matching entries.",
  deleteWarning:
    "Delete archive removes every moment, transcript, bookmark, and audio file on this device. This cannot be undone.",
  encryptedBackupPlaceholder:
    "Encrypted cloud backup is available from Account when signed in. Local import works anytime.",
} as const;
