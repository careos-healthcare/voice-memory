import { ONBOARDING_ACCOUNT } from "@/lib/onboarding/onboarding-copy";

/** User-facing encrypted sync copy. */
export const ENCRYPTED_SYNC_COPY = {
  encryptedBeforeLeave: ONBOARDING_ACCOUNT.backupLead,
  archiveNotServer: ONBOARDING_ACCOUNT.continuitySignedIn,
  serverStoresCiphertext:
    "Our servers store encrypted blobs only — never raw transcripts, audio, or reflection text.",
  restoreWarning:
    "Restore merges your encrypted backup with this device. You will see a preview first.",
} as const;

export { SYNC_FAILURE_COPY } from "@/lib/sync/sync-health";
