import { readAllCallbackReviews } from "@/lib/debug/callback-review-labels";
import { getReflectionGoal } from "@/lib/reflection-goal";
import { getAllBookmarks } from "@/lib/reflection-bookmarks";
import { isListeningModeEnabled } from "@/lib/listening-mode";
import { isFullDetailEnabled } from "@/lib/quiet-mode";
import { getReminderPreferences } from "@/lib/reminder-preferences";
import { getAllEntries } from "@/lib/storage";
import { getAudio } from "@/lib/audio-storage";
import { getPhoto, listPhotoEntryIds } from "@/lib/photo-storage";
import { validateArchivePhotoIntegrity } from "@/lib/photo/integrity";
import { PHOTO_EVENTS, trackPhotoEvent } from "@/lib/local-analytics";
import { attachPermanenceManifest } from "@/lib/archive/archive-guarantees";
import { slugExportDate } from "@/lib/memory-export";
import {
  getStoredVisualTone,
  isAutoTimeOfDayToneEnabled,
} from "@/lib/personalization/visual-tone";
import { isPhotoAttachmentEnabled } from "@/lib/personalization/photo-preferences";
import type {
  ArchiveAudioFile,
  VoiceMemoryArchivePackage,
} from "@/types/archive-permanence";
import type { ArchivePhotoFile } from "@/types/personalization";

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function audioExtension(mimeType: string): string {
  if (mimeType.includes("webm")) return "webm";
  if (mimeType.includes("mp4") || mimeType.includes("m4a")) return "m4a";
  if (mimeType.includes("ogg")) return "ogg";
  if (mimeType.includes("wav")) return "wav";
  return "audio";
}

export async function collectArchiveAudio(includeAudio: boolean): Promise<ArchiveAudioFile[]> {
  if (!includeAudio) return [];

  const files: ArchiveAudioFile[] = [];
  for (const entry of getAllEntries()) {
    if (!entry.audioId) continue;
    const audio = await getAudio(entry.id);
    if (!audio) continue;

    const buffer = await audio.blob.arrayBuffer();
    const ext = audioExtension(audio.mimeType);
    files.push({
      entryId: entry.id,
      mimeType: audio.mimeType,
      dataBase64: bytesToBase64(new Uint8Array(buffer)),
      filename: `audio/${entry.id}.${ext}`,
    });
  }

  return files;
}

export function buildArchiveSettingsSnapshot() {
  return {
    reminders: getReminderPreferences(),
    reflectionGoal: getReflectionGoal(),
    listeningMode: isListeningModeEnabled(),
    fullDetail: isFullDetailEnabled(),
    visualTone: getStoredVisualTone(),
    autoTimeOfDayTone: isAutoTimeOfDayToneEnabled(),
    photoAttachmentsEnabled: isPhotoAttachmentEnabled(),
  };
}

export async function collectArchivePhotos(includePhotos: boolean): Promise<ArchivePhotoFile[]> {
  if (!includePhotos || !isPhotoAttachmentEnabled()) return [];

  const files: ArchivePhotoFile[] = [];
  const entryIds = await listPhotoEntryIds();

  for (const entryId of entryIds) {
    const entry = getAllEntries().find((row) => row.id === entryId);
    const photo = await getPhoto(entryId);
    if (!photo) continue;

    const buffer = await photo.blob.arrayBuffer();
    const ext = photo.mimeType.includes("png")
      ? "png"
      : photo.mimeType.includes("webp")
        ? "webp"
        : "jpg";

    files.push({
      entryId,
      mimeType: photo.mimeType,
      dataBase64: bytesToBase64(new Uint8Array(buffer)),
      filename: `photos/${entryId}.${ext}`,
      attachedAt: entry?.photo?.attachedAt ?? photo.savedAt,
      byteLength: photo.byteLength ?? buffer.byteLength,
      contentHash: photo.contentHash ?? entry?.photo?.contentHash,
    });
  }

  return files;
}

/** Full portable archive — entries, bookmarks, settings, optional audio. */
export async function buildFullArchivePackage(
  includeAudio = true,
  includePhotos = true,
): Promise<VoiceMemoryArchivePackage> {
  const audio = await collectArchiveAudio(includeAudio);
  const photos = await collectArchivePhotos(includePhotos);
  const entries = getAllEntries();

  const photoIntegrity = validateArchivePhotoIntegrity(entries, photos);
  if (!photoIntegrity.valid) {
    throw new Error("Photo archive integrity check failed before export.");
  }

  if (photos.length > 0) {
    trackPhotoEvent(PHOTO_EVENTS.exported, {
      photoCount: String(photos.length),
    });
  }

  return attachPermanenceManifest({
    format: "voicememory-archive",
    version: 1,
    exportedAt: new Date().toISOString(),
    entries,
    bookmarks: getAllBookmarks(),
    settings: buildArchiveSettingsSnapshot(),
    memoryReviewLabels: readAllCallbackReviews(),
    audio: audio.length > 0 ? audio : undefined,
    photos: photos.length > 0 ? photos : undefined,
  });
}

export function downloadBlob(filename: string, blob: Blob): void {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

export function downloadArchiveJson(archive: VoiceMemoryArchivePackage): void {
  downloadBlob(
    `voicememory-archive-${slugExportDate()}.json`,
    new Blob([JSON.stringify(archive, null, 2)], { type: "application/json" }),
  );
}

export function downloadArchiveMarkdown(markdown: string): void {
  downloadBlob(
    `voicememory-archive-${slugExportDate()}.md`,
    new Blob([markdown], { type: "text/markdown;charset=utf-8" }),
  );
}
