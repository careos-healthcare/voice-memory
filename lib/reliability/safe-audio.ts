import { getAudio, saveAudio } from "@/lib/audio-storage";
import type { SaveAudioResult } from "@/types/storage-reliability";

const DEFAULT_ATTEMPTS = 3;

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

async function verifyAudioSaved(
  entryId: string,
  expectedSize: number,
): Promise<boolean> {
  const stored = await getAudio(entryId);
  if (!stored?.blob) return false;
  return stored.blob.size === expectedSize;
}

/** Save audio with retries and post-write verification. */
export async function saveAudioSafe(
  entryId: string,
  blob: Blob,
  mimeType?: string,
  maxAttempts: number = DEFAULT_ATTEMPTS,
): Promise<SaveAudioResult> {
  const resolvedMime = mimeType ?? (blob.type || "audio/webm");

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await saveAudio(entryId, blob, resolvedMime);
      const verified = await verifyAudioSaved(entryId, blob.size);
      if (verified) {
        return { saved: true, entryId };
      }
    } catch {
      // Retry below
    }

    if (attempt < maxAttempts) {
      await delay(120 * attempt);
    }
  }

  return { saved: false, entryId };
}

export async function saveDraftAudioSafe(
  draftId: string,
  blob: Blob,
  mimeType?: string,
): Promise<SaveAudioResult> {
  return saveAudioSafe(`draft-${draftId}`, blob, mimeType);
}

export async function promoteDraftAudio(
  draftId: string,
  entryId: string,
): Promise<boolean> {
  const draftKey = `draft-${draftId}`;
  const stored = await getAudio(draftKey);
  if (!stored?.blob) return false;

  const result = await saveAudioSafe(entryId, stored.blob, stored.mimeType);
  return result.saved;
}
