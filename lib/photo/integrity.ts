import { getPhoto, listPhotoEntryIds } from "@/lib/photo-storage";
import type { JournalEntry } from "@/types/journal";
import type { ArchivePhotoFile } from "@/types/personalization";
import type { IntegrityIssue } from "@/types/storage-reliability";

export interface PhotoIntegritySummary {
  photoCount: number;
  entriesWithPhotoMeta: number;
  brokenPhotoReferences: number;
  orphanPhotoBlobs: number;
  restoreReady: boolean;
  issues: IntegrityIssue[];
}

export async function hashPhotoBlob(blob: Blob): Promise<string> {
  if (typeof crypto !== "undefined" && crypto.subtle) {
    const buffer = await blob.arrayBuffer();
    const digest = await crypto.subtle.digest("SHA-256", buffer);
    return Array.from(new Uint8Array(digest))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("")
      .slice(0, 16);
  }

  return `${blob.size}:${blob.type}`;
}

export async function inspectPhotoIntegrity(
  entries: JournalEntry[],
): Promise<PhotoIntegritySummary> {
  const photoIds = new Set(await listPhotoEntryIds());
  const entriesWithPhoto = entries.filter((entry) => entry.photo?.photoId);
  const issues: IntegrityIssue[] = [];
  let brokenPhotoReferences = 0;

  for (const entry of entriesWithPhoto) {
    if (!photoIds.has(entry.id)) {
      brokenPhotoReferences += 1;
      issues.push({
        type: "missing_photo_reference",
        entryId: entry.id,
        detail: "Entry photo metadata without IndexedDB blob",
      });
    }
  }

  const metaEntryIds = new Set(entriesWithPhoto.map((entry) => entry.id));
  let orphanPhotoBlobs = 0;

  for (const entryId of photoIds) {
    if (!metaEntryIds.has(entryId)) {
      orphanPhotoBlobs += 1;
      issues.push({
        type: "orphan_photo_blob",
        entryId,
        detail: "Photo blob without entry metadata",
      });
    }
  }

  return {
    photoCount: photoIds.size,
    entriesWithPhotoMeta: entriesWithPhoto.length,
    brokenPhotoReferences,
    orphanPhotoBlobs,
    restoreReady: brokenPhotoReferences === 0 && orphanPhotoBlobs === 0,
    issues,
  };
}

export interface ArchivePhotoIntegrityResult {
  valid: boolean;
  photoCount: number;
  missingBlobs: number;
  orphanFiles: number;
  invalidPayloads: number;
  issues: Array<{ level: "error" | "warning"; message: string; entryId?: string }>;
}

/** Check archive photo payloads before export or restore. */
export function validateArchivePhotoIntegrity(
  entries: JournalEntry[],
  photos: ArchivePhotoFile[] | undefined,
): ArchivePhotoIntegrityResult {
  const files = photos ?? [];
  const entryIdsWithMeta = new Set(
    entries.filter((entry) => entry.photo?.photoId).map((entry) => entry.id),
  );
  const fileIds = new Set(files.map((file) => file.entryId));

  const issues: ArchivePhotoIntegrityResult["issues"] = [];
  let missingBlobs = 0;
  let orphanFiles = 0;
  let invalidPayloads = 0;

  for (const entryId of entryIdsWithMeta) {
    if (!fileIds.has(entryId)) {
      missingBlobs += 1;
      issues.push({
        level: "warning",
        entryId,
        message: "Reflection photo metadata without archive file",
      });
    }
  }

  for (const file of files) {
    if (!entryIdsWithMeta.has(file.entryId)) {
      orphanFiles += 1;
      issues.push({
        level: "warning",
        entryId: file.entryId,
        message: "Archive photo file without matching reflection metadata",
      });
    }

    if (!file.dataBase64?.trim()) {
      invalidPayloads += 1;
      issues.push({
        level: "error",
        entryId: file.entryId,
        message: "Archive photo file is empty",
      });
      continue;
    }

    try {
      atob(file.dataBase64.slice(0, 64));
    } catch {
      invalidPayloads += 1;
      issues.push({
        level: "error",
        entryId: file.entryId,
        message: "Archive photo file has invalid encoding",
      });
    }
  }

  return {
    valid: invalidPayloads === 0,
    photoCount: files.length,
    missingBlobs,
    orphanFiles,
    invalidPayloads,
    issues,
  };
}

export async function verifyLocalPhotoBlob(entryId: string): Promise<boolean> {
  const stored = await getPhoto(entryId);
  return Boolean(stored?.blob?.size);
}
