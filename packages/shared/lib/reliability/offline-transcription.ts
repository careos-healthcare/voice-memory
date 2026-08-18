import { saveRecoveryDraft } from "@/lib/reliability/draft-recovery";
import { saveDraftAudioSafe } from "@/lib/reliability/safe-audio";

export const OFFLINE_TRANSCRIPTION_SAVED_COPY =
  "Saved on this device. Transcription needs internet.";

export const OFFLINE_TRANSCRIPTION_RETRY_HINT =
  "Try again when you are back online.";

export function isNetworkFetchError(error: unknown): boolean {
  if (error instanceof TypeError) {
    const msg = error.message.toLowerCase();
    return msg.includes("fetch") || msg.includes("network");
  }
  if (error instanceof Error) {
    return /failed to fetch|network error|load failed|offline/i.test(error.message);
  }
  return false;
}

export function isLikelyOffline(): boolean {
  if (typeof navigator === "undefined") return false;
  return navigator.onLine === false;
}

export function sanitizeRecordingErrorMessage(message: string): string {
  if (/failed to fetch|network error|load failed/i.test(message)) {
    return OFFLINE_TRANSCRIPTION_SAVED_COPY;
  }
  return message;
}

/** Preserve audio locally when transcription cannot reach the server. */
export async function saveOfflineRecordingDraft(
  blob: Blob,
  durationSeconds: number,
  mimeType: string,
): Promise<string> {
  const entryId = crypto.randomUUID();
  const audioResult = await saveDraftAudioSafe(entryId, blob, mimeType);

  saveRecoveryDraft({
    id: entryId,
    transcript: "",
    durationSeconds,
    reflectionPending: true,
    audioId: audioResult.saved ? `draft-${entryId}` : undefined,
    reason: "unexpected_stop",
  });

  return entryId;
}
