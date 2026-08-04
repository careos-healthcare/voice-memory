"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { ImagePlus, RefreshCw, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { PHOTO_EVENTS, trackPhotoEvent } from "@/lib/local-analytics";
import { compressPhotoForStorage } from "@/lib/photo/compress";
import { deletePhoto, getPhoto, savePhoto } from "@/lib/photo-storage";
import { isPhotoAttachmentEnabled } from "@/lib/personalization/photo-preferences";
import { getEntry, saveEntry } from "@/lib/storage";
import type { EntryPhotoMeta } from "@/types/personalization";

interface EntryPhotoAttachmentProps {
  entryId: string;
  photo?: EntryPhotoMeta;
  onPhotoChange: (photo?: EntryPhotoMeta) => void;
  /** Hide attach UI until expanded — existing photos still render. */
  collapsed?: boolean;
}

type AttachPhase = "idle" | "compressing" | "saving" | "saved" | "error";

/** Quiet single-photo attachment — no feed, no filters. */
export function EntryPhotoAttachment({
  entryId,
  photo,
  onPhotoChange,
  collapsed = false,
}: EntryPhotoAttachmentProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const sectionRef = useRef<HTMLElement>(null);
  const longPressTimerRef = useRef<number | null>(null);
  const pendingFileRef = useRef<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [enabled, setEnabled] = useState(true);
  const [phase, setPhase] = useState<AttachPhase>("idle");
  const [dragActive, setDragActive] = useState(false);
  const [showActions, setShowActions] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [savedHint, setSavedHint] = useState(false);

  const busy = phase === "compressing" || phase === "saving";

  useEffect(() => {
    setEnabled(isPhotoAttachmentEnabled());
    const onPref = () => setEnabled(isPhotoAttachmentEnabled());
    window.addEventListener("voicememory:photo-preferences", onPref);
    return () => window.removeEventListener("voicememory:photo-preferences", onPref);
  }, []);

  useEffect(() => {
    let active = true;
    let objectUrl: string | null = null;

    void (async () => {
      if (!photo?.photoId) {
        if (active) setPreviewUrl(null);
        return;
      }
      const stored = await getPhoto(entryId);
      if (!stored || !active) return;
      objectUrl = URL.createObjectURL(stored.blob);
      setPreviewUrl(objectUrl);
    })();

    return () => {
      active = false;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [entryId, photo?.photoId, photo?.attachedAt]);

  const persistPhotoMeta = useCallback(
    (meta: EntryPhotoMeta) => {
      const entry = getEntry(entryId);
      if (entry) {
        saveEntry({ ...entry, photo: meta });
      }
      onPhotoChange(meta);
    },
    [entryId, onPhotoChange],
  );

  const attachPhoto = useCallback(
    async (file: File, source: "file" | "drag" | "paste" | "replace") => {
      if (!file.type.startsWith("image/")) return;

      const isReplace = Boolean(photo?.photoId);
      pendingFileRef.current = file;
      setErrorMessage(null);
      setSavedHint(false);
      setPhase("compressing");

      try {
        const compressed = await compressPhotoForStorage(file);
        setPhase("saving");

        const saved = await savePhoto(entryId, compressed.blob, compressed.mimeType, {
          originalByteLength: compressed.originalByteLength,
          width: compressed.width,
          height: compressed.height,
        });

        const meta: EntryPhotoMeta = {
          photoId: entryId,
          mimeType: saved.mimeType,
          attachedAt: saved.savedAt,
          filename: file.name,
          byteLength: saved.byteLength,
          width: saved.width,
          height: saved.height,
          contentHash: saved.contentHash,
          compressed: compressed.byteLength < compressed.originalByteLength,
        };

        persistPhotoMeta(meta);
        setShowActions(false);
        setPhase("saved");
        setSavedHint(true);

        if (source === "drag") {
          trackPhotoEvent(PHOTO_EVENTS.dragAttached, { entryId });
        } else if (source === "paste") {
          trackPhotoEvent(PHOTO_EVENTS.pasteAttached, { entryId });
        } else if (isReplace || source === "replace") {
          trackPhotoEvent(PHOTO_EVENTS.replaced, { entryId });
        }

        window.setTimeout(() => {
          setSavedHint(false);
          setPhase("idle");
        }, 2400);
      } catch (error) {
        setPhase("error");
        setErrorMessage(
          error instanceof Error ? error.message : "Photo could not be saved.",
        );
      } finally {
        pendingFileRef.current = null;
      }
    },
    [entryId, persistPhotoMeta, photo?.photoId],
  );

  const removePhoto = async () => {
    setPhase("saving");
    setErrorMessage(null);
    try {
      await deletePhoto(entryId);
      const entry = getEntry(entryId);
      if (entry) {
        const next = { ...entry };
        delete next.photo;
        saveEntry(next);
      }
      onPhotoChange(undefined);
      setPreviewUrl(null);
      setShowActions(false);
      setPhase("idle");
    } catch (error) {
      setPhase("error");
      setErrorMessage(
        error instanceof Error ? error.message : "Photo could not be removed.",
      );
    }
  };

  const retryAttach = () => {
    const file = pendingFileRef.current;
    if (file) {
      void attachPhoto(file, "file");
      return;
    }
    setPhase("idle");
    setErrorMessage(null);
    inputRef.current?.click();
  };

  const handleDragOver = (event: React.DragEvent) => {
    event.preventDefault();
    if (!busy) setDragActive(true);
  };

  const handleDragLeave = (event: React.DragEvent) => {
    if (event.currentTarget.contains(event.relatedTarget as Node)) return;
    setDragActive(false);
  };

  const handleDrop = (event: React.DragEvent) => {
    event.preventDefault();
    setDragActive(false);
    if (busy) return;
    const file = event.dataTransfer.files?.[0];
    if (file) void attachPhoto(file, "drag");
  };

  useEffect(() => {
    const node = sectionRef.current;
    if (!node || !enabled) return;

    const onPaste = (event: ClipboardEvent) => {
      if (busy) return;
      const items = event.clipboardData?.items;
      if (!items) return;

      for (const item of items) {
        if (!item.type.startsWith("image/")) continue;
        const file = item.getAsFile();
        if (!file) continue;
        event.preventDefault();
        void attachPhoto(file, "paste");
        break;
      }
    };

    node.addEventListener("paste", onPaste);
    return () => node.removeEventListener("paste", onPaste);
  }, [attachPhoto, busy, enabled]);

  const clearLongPress = () => {
    if (longPressTimerRef.current !== null) {
      window.clearTimeout(longPressTimerRef.current);
      longPressTimerRef.current = null;
    }
  };

  const handleTouchStart = () => {
    clearLongPress();
    longPressTimerRef.current = window.setTimeout(() => {
      setShowActions(true);
    }, 520);
  };

  if (!enabled) return null;
  if (collapsed && !photo?.photoId) return null;

  return (
    <section
      ref={sectionRef}
      tabIndex={-1}
      className="space-y-3 outline-none"
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {previewUrl ? (
        <figure
          className="relative overflow-hidden rounded-xl border border-white/[0.06]"
          onTouchStart={handleTouchStart}
          onTouchEnd={clearLongPress}
          onTouchCancel={clearLongPress}
          onContextMenu={(event) => {
            event.preventDefault();
            setShowActions(true);
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={previewUrl}
            alt=""
            className="max-h-72 w-full object-cover object-center opacity-90"
          />
          {(showActions || phase === "error") && (
            <div className="absolute inset-x-0 bottom-0 flex flex-wrap gap-2 bg-gradient-to-t from-black/70 to-transparent p-3">
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="bg-black/40 text-zinc-200 hover:bg-black/60"
                disabled={busy}
                onClick={() => inputRef.current?.click()}
              >
                <RefreshCw className="h-4 w-4" />
                Replace
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="bg-black/40 text-zinc-200 hover:bg-black/60"
                disabled={busy}
                onClick={() => void removePhoto()}
              >
                <X className="h-4 w-4" />
                Remove
              </Button>
            </div>
          )}
          <p className="px-1 pt-2 text-xs text-zinc-600">
            This photo stays with this moment.
          </p>
        </figure>
      ) : (
        <div
          className={`rounded-xl border border-dashed px-4 py-5 transition-colors ${
            dragActive
              ? "border-violet-300/40 bg-violet-500/[0.06]"
              : "border-white/[0.08] bg-white/[0.02]"
          }`}
        >
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            capture="environment"
            className="hidden"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) {
                void attachPhoto(file, photo?.photoId ? "replace" : "file");
              }
              event.target.value = "";
            }}
          />
          <div className="space-y-2 text-center">
            <p className="text-sm text-zinc-400">Add a photo to this moment.</p>
            <p className="text-xs text-zinc-600">
              Drop an image, paste from clipboard, or tap to attach.
            </p>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="text-zinc-500 hover:text-zinc-300"
              disabled={busy}
              onClick={() => inputRef.current?.click()}
            >
              <ImagePlus className="h-4 w-4" />
              Attach photo
            </Button>
          </div>
        </div>
      )}

      {phase === "compressing" || phase === "saving" ? (
        <p className="text-xs text-zinc-500" aria-live="polite">
          {phase === "compressing" ? "Preparing photo…" : "Saving with this moment…"}
        </p>
      ) : null}

      {savedHint ? (
        <p className="text-xs text-zinc-500" aria-live="polite">
          Photo saved with this moment.
        </p>
      ) : null}

      {phase === "error" && errorMessage ? (
        <div className="flex flex-wrap items-center gap-2 text-xs text-amber-200/90">
          <span>{errorMessage}</span>
          <Button type="button" size="sm" variant="secondary" onClick={retryAttach}>
            Try again
          </Button>
        </div>
      ) : null}
    </section>
  );
}
