"use client";

import type { ArchiveImportPreview, ArchiveRestoreMode } from "@/types/archive-permanence";

interface ArchiveImportPreviewProps {
  preview: ArchiveImportPreview;
  mode: ArchiveRestoreMode;
  includeSettings: boolean;
  includeAudio: boolean;
  includePhotos: boolean;
  onModeChange: (mode: ArchiveRestoreMode) => void;
  onIncludeSettingsChange: (value: boolean) => void;
  onIncludeAudioChange: (value: boolean) => void;
  onIncludePhotosChange: (value: boolean) => void;
}

export function ArchiveImportPreviewPanel({
  preview,
  mode,
  includeSettings,
  includeAudio,
  includePhotos,
  onModeChange,
  onIncludeSettingsChange,
  onIncludeAudioChange,
  onIncludePhotosChange,
}: ArchiveImportPreviewProps) {
  if (!preview.package) return null;

  return (
    <div className="space-y-4 rounded-2xl border border-white/[0.08] bg-zinc-900/40 p-4">
      <div className="space-y-1 text-sm text-zinc-400">
        <p>
          {preview.entryCount} moment{preview.entryCount === 1 ? "" : "s"}
          {preview.bookmarkCount > 0
            ? ` · ${preview.bookmarkCount} bookmark${preview.bookmarkCount === 1 ? "" : "s"}`
            : ""}
          {preview.audioCount > 0
            ? ` · ${preview.audioCount} audio file${preview.audioCount === 1 ? "" : "s"}`
            : ""}
          {preview.photoCount > 0
            ? ` · ${preview.photoCount} photo${preview.photoCount === 1 ? "" : "s"}`
            : ""}
        </p>
        {preview.dateRange.from ? (
          <p className="text-zinc-500">
            {preview.dateRange.from} → {preview.dateRange.to}
          </p>
        ) : null}
        {preview.localOverlapCount > 0 ? (
          <p className="text-amber-200/80">
            {preview.localOverlapCount} already on this device — merge updates matching entries.
          </p>
        ) : null}
      </div>

      {preview.issues.map((issue) => (
        <p
          key={issue.message}
          className={issue.level === "error" ? "text-sm text-red-300/90" : "text-sm text-amber-200/80"}
        >
          {issue.message}
        </p>
      ))}

      <div className="flex flex-wrap gap-4 text-sm text-zinc-400">
        <label className="flex items-center gap-2">
          <input
            type="radio"
            name="restore-mode"
            checked={mode === "merge"}
            onChange={() => onModeChange("merge")}
          />
          Merge with this device
        </label>
        <label className="flex items-center gap-2">
          <input
            type="radio"
            name="restore-mode"
            checked={mode === "replace"}
            onChange={() => onModeChange("replace")}
          />
          Replace everything
        </label>
      </div>

      <div className="flex flex-col gap-2 text-sm text-zinc-500">
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={includeSettings}
            onChange={(event) => onIncludeSettingsChange(event.target.checked)}
            disabled={!preview.hasSettings}
          />
          Include settings and review labels from archive
        </label>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={includeAudio}
            onChange={(event) => onIncludeAudioChange(event.target.checked)}
            disabled={preview.audioCount === 0}
          />
          Restore audio recordings
        </label>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={includePhotos}
            onChange={(event) => onIncludePhotosChange(event.target.checked)}
            disabled={preview.photoCount === 0}
          />
          Restore photo memory anchors
        </label>
      </div>
    </div>
  );
}
