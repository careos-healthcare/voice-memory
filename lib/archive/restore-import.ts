import { saveAudio } from "@/lib/audio-storage";
import { deleteAllEntriesAndAudio } from "@/lib/data-controls";
import { setListeningModeEnabled } from "@/lib/listening-mode";
import { setFullDetailEnabled } from "@/lib/quiet-mode";
import { savePhoto } from "@/lib/photo-storage";
import { getAllBookmarks } from "@/lib/reflection-bookmarks";
import { setReflectionGoal } from "@/lib/reflection-goal";
import { saveReminderPreferences } from "@/lib/reminder-preferences";
import { getAllEntries } from "@/lib/storage";
import type {
  ArchiveRestoreOptions,
  VoiceMemoryArchivePackage,
} from "@/types/archive-permanence";

function base64ToBlob(base64: string, mimeType: string): Blob {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return new Blob([bytes], { type: mimeType });
}

function applySettings(archive: VoiceMemoryArchivePackage): void {
  saveReminderPreferences(archive.settings.reminders);
  setReflectionGoal(archive.settings.reflectionGoal);
  setListeningModeEnabled(archive.settings.listeningMode);
  setFullDetailEnabled(archive.settings.fullDetail);

  if (archive.memoryReviewLabels.length > 0) {
    localStorage.setItem(
      "voicememory_callback_reviews",
      JSON.stringify(archive.memoryReviewLabels),
    );
  }
}

async function restoreAudio(archive: VoiceMemoryArchivePackage): Promise<number> {
  if (!archive.audio?.length) return 0;

  let restored = 0;
  for (const file of archive.audio) {
    const blob = base64ToBlob(file.dataBase64, file.mimeType);
    await saveAudio(file.entryId, blob, file.mimeType);
    restored += 1;
  }
  return restored;
}

async function restorePhotos(archive: VoiceMemoryArchivePackage): Promise<number> {
  if (!archive.photos?.length) return 0;

  let restored = 0;
  for (const file of archive.photos) {
    const blob = base64ToBlob(file.dataBase64, file.mimeType);
    await savePhoto(file.entryId, blob, file.mimeType, {
      originalByteLength: file.byteLength,
    });
    restored += 1;
  }
  return restored;
}

function writeEntries(entries: VoiceMemoryArchivePackage["entries"]): void {
  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  localStorage.setItem("voicememory_entries", JSON.stringify(sorted));
}

function writeBookmarks(bookmarks: VoiceMemoryArchivePackage["bookmarks"]): void {
  localStorage.setItem("voicememory_reflection_bookmarks", JSON.stringify(bookmarks));
}

function mergeEntries(archive: VoiceMemoryArchivePackage): number {
  const byId = new Map(getAllEntries().map((entry) => [entry.id, entry]));
  for (const entry of archive.entries) {
    byId.set(entry.id, entry);
  }
  writeEntries([...byId.values()]);
  return archive.entries.length;
}

function mergeBookmarks(archive: VoiceMemoryArchivePackage): void {
  const byEntry = new Map(getAllBookmarks().map((bookmark) => [bookmark.entryId, bookmark]));
  for (const bookmark of archive.bookmarks) {
    byEntry.set(bookmark.entryId, bookmark);
  }
  writeBookmarks([...byEntry.values()]);
}

/** Restore archive with merge or replace — preview should be shown first. */
export async function restoreArchivePackage(
  archive: VoiceMemoryArchivePackage,
  options: ArchiveRestoreOptions,
): Promise<{ entries: number; audio: number; photos: number }> {
  if (options.mode === "replace") {
    await deleteAllEntriesAndAudio();
    writeEntries(archive.entries);
    writeBookmarks(archive.bookmarks);
    if (options.includeSettings) applySettings(archive);
  } else {
    mergeEntries(archive);
    mergeBookmarks(archive);
    if (options.includeSettings) applySettings(archive);
  }

  const audio = options.includeAudio ? await restoreAudio(archive) : 0;
  const photos = options.includePhotos ? await restorePhotos(archive) : 0;
  return { entries: archive.entries.length, audio, photos };
}

/** Delete all local archive data after explicit confirmation in UI. */
export async function deleteLocalArchive(): Promise<number> {
  return deleteAllEntriesAndAudio();
}
