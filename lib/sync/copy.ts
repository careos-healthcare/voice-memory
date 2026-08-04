import { ONBOARDING_ACCOUNT } from "@/lib/onboarding/onboarding-copy";
import { ACCOUNT_BACKUP } from "@/lib/product-copy";

/** User-facing encrypted sync copy. */
export const ENCRYPTED_SYNC_COPY = {
  encryptedBeforeLeave: ONBOARDING_ACCOUNT.backupLead,
  archiveNotServer: ACCOUNT_BACKUP.signedInLead,
  serverStoresCiphertext:
    "Our servers store encrypted blobs only — never raw transcripts, audio, or saved words.",
  restoreWarning:
    "Restore merges your encrypted backup with this device. You will see a preview first.",
} as const;

export { SYNC_FAILURE_COPY } from "@/lib/sync/sync-health";
