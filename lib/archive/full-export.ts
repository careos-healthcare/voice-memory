import { readAllCallbackReviews } from "@/lib/debug/callback-review-labels";
import { getReflectionGoal } from "@/lib/reflection-goal";
import { getAllBookmarks } from "@/lib/reflection-bookmarks";
import { isListeningModeEnabled } from "@/lib/listening-mode";
import { isFullDetailEnabled } from "@/lib/quiet-mode";
import { getReminderPreferences } from "@/lib/reminder-preferences";
import { getAllEntries } from "@/lib/storage";
import { getAudio } from "@/lib/audio-storage";
import { slugExportDate } from "@/lib/memory-export";
import type {
  ArchiveAudioFile,
  VoiceMemoryArchivePackage,
} from "@/types/archive-permanence";

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
  };
}

/** Full portable archive — entries, bookmarks, settings, optional audio. */
export async function buildFullArchivePackage(
  includeAudio = true,
): Promise<VoiceMemoryArchivePackage> {
  const audio = await collectArchiveAudio(includeAudio);

  return {
    format: "voicememory-archive",
    version: 1,
    exportedAt: new Date().toISOString(),
    entries: getAllEntries(),
    bookmarks: getAllBookmarks(),
    settings: buildArchiveSettingsSnapshot(),
    memoryReviewLabels: readAllCallbackReviews(),
    audio: audio.length > 0 ? audio : undefined,
  };
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
