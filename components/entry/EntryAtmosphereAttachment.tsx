"use client";

import { useCallback, useEffect, useState } from "react";
import { Sparkles, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  trackAtmosphereCreated,
  trackAtmosphereDeleted,
} from "@/lib/atmosphere/atmosphere-observation";
import { deleteAtmosphereImage, getAtmosphereImage, saveAtmosphereImage } from "@/lib/atmosphere/atmosphere-storage";
import {
  ATMOSPHERE_STYLE_OPTIONS,
  buildAtmosphereMeta,
  buildAtmospherePrompt,
  buildAtmosphereSignals,
  extractPhotoColorHints,
  getStoredAtmosphereStyle,
  requestAtmosphereImage,
  setStoredAtmosphereStyle,
} from "@/lib/atmosphere/memory-atmosphere";
import { getPhoto } from "@/lib/photo-storage";
import { getEntry, saveEntry } from "@/lib/storage";
import type { EntryAtmosphereMeta, AtmosphereStyle } from "@/types/atmosphere";
import type { JournalEntry } from "@/types/journal";

interface EntryAtmosphereAttachmentProps {
  entryId: string;
  entry: JournalEntry;
  atmosphere?: EntryAtmosphereMeta;
  onAtmosphereChange: (atmosphere?: EntryAtmosphereMeta) => void;
}

type Phase = "idle" | "creating" | "saved" | "error";

export function EntryAtmosphereAttachment({
  entryId,
  entry,
  atmosphere,
  onAtmosphereChange,
}: EntryAtmosphereAttachmentProps) {
  const [expanded, setExpanded] = useState(false);
  const [style, setStyle] = useState<AtmosphereStyle>(getStoredAtmosphereStyle());
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [phase, setPhase] = useState<Phase>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const busy = phase === "creating";
  const hasAtmosphere = Boolean(atmosphere?.atmosphereId);

  useEffect(() => {
    let active = true;
    let objectUrl: string | null = null;

    void (async () => {
      if (!atmosphere?.atmosphereId) {
        if (active) setPreviewUrl(null);
        return;
      }
      const stored = await getAtmosphereImage(entryId);
      if (!stored || !active) return;
      objectUrl = URL.createObjectURL(stored.blob);
      setPreviewUrl(objectUrl);
    })();

    return () => {
      active = false;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [entryId, atmosphere?.atmosphereId, atmosphere?.createdAt]);

  const persistMeta = useCallback(
    (meta: EntryAtmosphereMeta) => {
      const current = getEntry(entryId);
      if (current) {
        saveEntry({ ...current, atmosphere: meta });
      }
      onAtmosphereChange(meta);
    },
    [entryId, onAtmosphereChange],
  );

  const createAtmosphere = async () => {
    setPhase("creating");
    setErrorMessage(null);
    setStoredAtmosphereStyle(style);

    try {
      let colorHints: string[] = [];
      if (entry.photo?.photoId) {
        const photo = await getPhoto(entryId);
        if (photo?.blob) {
          colorHints = await extractPhotoColorHints(photo.blob);
        }
      }

      const signals = buildAtmosphereSignals(entry, colorHints);
      const prompt = buildAtmospherePrompt(style, signals);
      const { blob, source, width, height } = await requestAtmosphereImage(prompt, style, signals);

      await saveAtmosphereImage(entryId, blob, { width, height });
      const meta = buildAtmosphereMeta(entryId, style, prompt, source, width, height, blob.size);
      persistMeta(meta);
      trackAtmosphereCreated(entryId, style, source);
      setExpanded(false);
      setPhase("saved");
      window.setTimeout(() => setPhase("idle"), 2400);
    } catch (error) {
      setPhase("error");
      setErrorMessage(error instanceof Error ? error.message : "Atmosphere could not be created.");
    }
  };

  const removeAtmosphere = async () => {
    setPhase("creating");
    setErrorMessage(null);
    try {
      await deleteAtmosphereImage(entryId);
      const current = getEntry(entryId);
      if (current) {
        const next = { ...current };
        delete next.atmosphere;
        saveEntry(next);
      }
      onAtmosphereChange(undefined);
      setPreviewUrl(null);
      trackAtmosphereDeleted(entryId);
      setPhase("idle");
    } catch (error) {
      setPhase("error");
      setErrorMessage(error instanceof Error ? error.message : "Atmosphere could not be removed.");
    }
  };

  if (hasAtmosphere && previewUrl) {
    return (
      <section className="space-y-3">
        <figure className="relative overflow-hidden rounded-xl border border-white/[0.06]">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={previewUrl}
            alt=""
            className="max-h-56 w-full object-cover object-center opacity-85"
          />
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="absolute right-2 top-2 bg-black/40 text-zinc-200 hover:bg-black/60"
            disabled={busy}
            onClick={() => void removeAtmosphere()}
          >
            <Trash2 className="h-4 w-4" />
            Remove
          </Button>
        </figure>
        <p className="text-xs text-zinc-600">A quiet visual, not a memory.</p>
        <p className="text-xs text-zinc-700">
          Generated images may not match what happened.
        </p>
      </section>
    );
  }

  if (!expanded) {
    return (
      <section className="space-y-2">
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="text-zinc-500 hover:text-zinc-300"
          onClick={() => setExpanded(true)}
        >
          <Sparkles className="h-4 w-4" />
          Create quiet atmosphere
        </Button>
      </section>
    );
  }

  return (
    <section className="space-y-4 rounded-xl border border-white/[0.06] bg-white/[0.02] px-4 py-4">
      <div className="space-y-1">
        <p className="text-sm text-zinc-400">A quiet visual, not a memory.</p>
        <p className="text-xs text-zinc-600">
          Generated images may not match what happened.
        </p>
      </div>

      <div className="grid gap-2 sm:grid-cols-2">
        {ATMOSPHERE_STYLE_OPTIONS.map((option) => (
          <Button
            key={option.id}
            type="button"
            variant={style === option.id ? "default" : "secondary"}
            size="sm"
            className="h-auto flex-col items-start gap-1 px-3 py-3 text-left"
            disabled={busy}
            onClick={() => setStyle(option.id)}
          >
            <span className="text-sm">{option.label}</span>
            <span className="text-xs font-normal text-zinc-500">{option.detail}</span>
          </Button>
        ))}
      </div>

      <div className="flex flex-wrap gap-2">
        <Button type="button" size="sm" disabled={busy} onClick={() => void createAtmosphere()}>
          {busy ? "Creating…" : "Create atmosphere"}
        </Button>
        <Button
          type="button"
          size="sm"
          variant="ghost"
          disabled={busy}
          onClick={() => setExpanded(false)}
        >
          Cancel
        </Button>
      </div>

      {phase === "saved" ? (
        <p className="text-xs text-zinc-500" aria-live="polite">
          Atmosphere saved with this reflection.
        </p>
      ) : null}

      {phase === "error" && errorMessage ? (
        <p className="text-xs text-amber-200/90">{errorMessage}</p>
      ) : null}
    </section>
  );
}
