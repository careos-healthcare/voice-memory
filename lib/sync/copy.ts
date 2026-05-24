/** User-facing encrypted sync copy. */
export const ENCRYPTED_SYNC_COPY = {
  encryptedBeforeLeave:
    "Your archive is encrypted before it leaves this device.",
  archiveNotServer:
    "VoiceMemory should feel like your archive, not our server.",
  serverStoresCiphertext:
    "Our servers store encrypted blobs only — never raw transcripts, audio, or reflection text.",
  restoreWarning:
    "Restore replaces local archive data on this device with your encrypted backup.",
} as const;
