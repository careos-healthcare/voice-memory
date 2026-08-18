import { getAudio } from "@/lib/audio-storage";
import { getAllEntries } from "@/lib/storage";
import type { AudioBackupPlan, AudioBackupPlanItem } from "@/types/sync";

/**
 * Encrypted audio backup plan — same client-side encryption as journal snapshots.
 * Each recording becomes its own encrypted blob (`audio_backup`) keyed by entryId.
 * Server stores ciphertext only; restore decrypts locally back into IndexedDB.
 */
export function buildEncryptedAudioBackupPlan(): AudioBackupPlan {
  const items: AudioBackupPlanItem[] = [];

  for (const entry of getAllEntries()) {
    if (!entry.audioId) continue;
    items.push({
      entryId: entry.id,
      audioId: entry.audioId,
      durationSeconds: entry.durationSeconds,
      status: "pending",
    });
  }

  return {
    items,
    note:
      "Audio is encrypted on this device before upload. ArchiveMe servers never receive raw recordings.",
  };
}

export async function readAudioBlobForBackup(entryId: string): Promise<Blob | null> {
  const audio = await getAudio(entryId);
  return audio?.blob ?? null;
}

export function markAudioBackupQueued(plan: AudioBackupPlan, entryId: string): AudioBackupPlan {
  return {
    ...plan,
    items: plan.items.map((item) =>
      item.entryId === entryId ? { ...item, status: "queued" } : item,
    ),
  };
}

export function markAudioBackupComplete(plan: AudioBackupPlan, entryId: string): AudioBackupPlan {
  return {
    ...plan,
    items: plan.items.map((item) =>
      item.entryId === entryId ? { ...item, status: "backed_up" } : item,
    ),
  };
}
