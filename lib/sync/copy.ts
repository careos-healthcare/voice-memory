/** User-facing encrypted sync copy. */
export const ENCRYPTED_SYNC_COPY = {
  encryptedBeforeLeave:
    "Your archive is encrypted before it leaves this device.",
  archiveNotServer:
    "VoiceMemory should feel like your archive, not our server.",
  serverStoresCiphertext:
    "Our servers store encrypted blobs only — never raw transcripts, audio, or reflection text.",
  restoreWarning:
    "Restore merges your encrypted backup with this device. You will see a preview first.",
} as const;

export { SYNC_FAILURE_COPY } from "@/lib/sync/sync-health";
