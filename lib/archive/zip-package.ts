import { strToU8, zipSync } from "fflate";

import { buildArchiveMarkdown } from "@/lib/archive/markdown-export";
import { slugExportDate } from "@/lib/memory-export";
import type { ArchiveMeArchivePackage } from "@/types/archive-permanence";

import { downloadBlob } from "@/lib/archive/full-export";

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/** Download ZIP with JSON, Markdown, and audio files. */
export function downloadArchiveZipPackage(archive: ArchiveMeArchivePackage): void {
  const markdown = buildArchiveMarkdown(archive);
  const files: Record<string, Uint8Array> = {
    "manifest.json": strToU8(
      JSON.stringify(
        {
          format: archive.format,
          version: archive.version,
          exportedAt: archive.exportedAt,
          entryCount: archive.entries.length,
          bookmarkCount: archive.bookmarks.length,
          audioCount: archive.audio?.length ?? 0,
          photoCount: archive.photos?.length ?? 0,
        },
        null,
        2,
      ),
    ),
    "archive.json": strToU8(JSON.stringify(archive, null, 2)),
    "reflections.md": strToU8(markdown),
    "README.txt": strToU8(
      [
        "ArchiveMe Archive Package",
        "",
        "archive.json — full structured archive",
        "reflections.md — readable export",
        "audio/ — recordings where available",
        "photos/ — memory anchor images where available",
        "",
        "Import this package from /archive in ArchiveMe.",
      ].join("\n"),
    ),
  };

  if (archive.audio) {
    for (const file of archive.audio) {
      files[file.filename] = base64ToBytes(file.dataBase64);
    }
  }

  if (archive.photos) {
    for (const file of archive.photos) {
      files[file.filename] = base64ToBytes(file.dataBase64);
    }
  }

  const zipped = zipSync(files, { level: 6 });
  downloadBlob(
    `archiveme-archive-${slugExportDate()}.zip`,
    new Blob([zipped], { type: "application/zip" }),
  );
}
