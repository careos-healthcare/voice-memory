"use client";

import { useEffect, useRef, useState } from "react";
import { ImagePlus, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { deletePhoto, getPhoto, savePhoto } from "@/lib/photo-storage";
import { isPhotoAttachmentEnabled } from "@/lib/personalization/photo-preferences";
import { getEntry, saveEntry } from "@/lib/storage";
import type { EntryPhotoMeta } from "@/types/personalization";

interface EntryPhotoAttachmentProps {
  entryId: string;
  photo?: EntryPhotoMeta;
  onPhotoChange: (photo?: EntryPhotoMeta) => void;
}

/** Quiet single-photo attachment — no feed, no filters. */
export function EntryPhotoAttachment({
  entryId,
  photo,
  onPhotoChange,
}: EntryPhotoAttachmentProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [enabled, setEnabled] = useState(true);
  const [busy, setBusy] = useState(false);

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

  if (!enabled) return null;

  const attachPhoto = async (file: File) => {
    if (!file.type.startsWith("image/")) return;
    setBusy(true);
    try {
      await savePhoto(entryId, file, file.type);
      const meta: EntryPhotoMeta = {
        photoId: entryId,
        mimeType: file.type,
        attachedAt: new Date().toISOString(),
        filename: file.name,
      };
      const entry = getEntry(entryId);
      if (entry) {
        saveEntry({ ...entry, photo: meta });
      }
      onPhotoChange(meta);
    } finally {
      setBusy(false);
    }
  };

  const removePhoto = async () => {
    setBusy(true);
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
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="space-y-3">
      {previewUrl ? (
        <figure className="relative overflow-hidden rounded-xl border border-white/[0.06]">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={previewUrl}
            alt=""
            className="max-h-72 w-full object-cover object-center opacity-90"
          />
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="absolute right-2 top-2 bg-black/40 text-zinc-200 hover:bg-black/60"
            disabled={busy}
            onClick={() => void removePhoto()}
          >
            <X className="h-4 w-4" />
            Remove
          </Button>
        </figure>
      ) : (
        <>
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) void attachPhoto(file);
              event.target.value = "";
            }}
          />
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="text-zinc-500 hover:text-zinc-300"
            disabled={busy}
            onClick={() => inputRef.current?.click()}
          >
            <ImagePlus className="h-4 w-4" />
            Attach a photo
          </Button>
        </>
      )}
    </section>
  );
}
