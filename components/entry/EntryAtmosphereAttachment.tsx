"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { RefreshCw, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  trackAtmosphereCreated,
  trackAtmosphereDeleted,
} from "@/lib/atmosphere/atmosphere-observation";
import { deleteAtmosphereImage, getAtmosphereImage, saveAtmosphereImage } from "@/lib/atmosphere/atmosphere-storage";
import {
  ATMOSPHERE_EXPAND_LABEL,
  ATMOSPHERE_GENERATE_ANOTHER,
  ATMOSPHERE_SECTION_DISCLAIMER,
  ATMOSPHERE_SECTION_TITLE,
  buildAtmospherePickerPresentation,
  pickEmotionalContextLine,
} from "@/lib/atmosphere/atmosphere-anchors";
import {
  buildAtmosphereMeta,
  buildAtmospherePrompt,
  buildAtmosphereSignals,
  extractPhotoColorHints,
  requestAtmosphereImage,
} from "@/lib/atmosphere/memory-atmosphere";
import { getPhoto } from "@/lib/photo-storage";
import { getEntry, saveEntry } from "@/lib/storage";
import type { AtmosphereChoice, EntryAtmosphereMeta } from "@/types/atmosphere";
import type { JournalEntry } from "@/types/journal";

interface EntryAtmosphereAttachmentProps {
  entryId: string;
  entry: JournalEntry;
  atmosphere?: EntryAtmosphereMeta;
  onAtmosphereChange: (atmosphere?: EntryAtmosphereMeta) => void;
  /** Hide create UI until expanded — existing atmosphere still renders. */
  collapsed?: boolean;
}

type Phase = "idle" | "creating" | "saved" | "error";

function AtmosphereChoiceCard({
  choice,
  variant,
  disabled,
  onSelect,
}: {
  choice: AtmosphereChoice;
  variant: "primary" | "alternate";
  disabled: boolean;
  onSelect: () => void;
}) {
  const isPrimary = variant === "primary";

  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onSelect}
      className={[
        "w-full text-left transition-colors",
        isPrimary
          ? "rounded-2xl border border-white/[0.08] bg-white/[0.04] px-5 py-5 hover:border-white/[0.12] hover:bg-white/[0.06] disabled:opacity-50"
          : "rounded-xl border border-white/[0.05] bg-white/[0.02] px-4 py-3 hover:border-white/[0.08] hover:bg-white/[0.04] disabled:opacity-50",
      ].join(" ")}
    >
      <p
        className={
          isPrimary
            ? "text-lg font-normal tracking-tight text-zinc-200"
            : "text-sm font-normal text-zinc-400"
        }
      >
        {choice.displayLabel}
      </p>
      <p className="mt-1.5 text-xs leading-relaxed text-zinc-600">{choice.hint}</p>
    </button>
  );
}

export function EntryAtmosphereAttachment({
  entryId,
  entry,
  atmosphere,
  onAtmosphereChange,
  collapsed = false,
}: EntryAtmosphereAttachmentProps) {
  const [expanded, setExpanded] = useState(false);
  const [rotateIndex, setRotateIndex] = useState(0);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [phase, setPhase] = useState<Phase>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const busy = phase === "creating";
  const hasAtmosphere = Boolean(atmosphere?.atmosphereId);

  const picker = useMemo(
    () => (expanded ? buildAtmospherePickerPresentation(entry) : null),
    [expanded, entry],
  );

  const contextLine = useMemo(
    () => (expanded ? pickEmotionalContextLine(entry) : null),
    [expanded, entry],
  );

  const rotatedAlternate = useMemo(() => {
    if (!picker) return null;
    const pool = picker.orderedChoices.filter(
      (row) => row.emotionalLabel !== picker.primary.emotionalLabel,
    );
    if (pool.length === 0) return picker.alternate;
    return pool[rotateIndex % pool.length] ?? picker.alternate;
  }, [picker, rotateIndex]);

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

  const createAtmosphere = async (choice: AtmosphereChoice) => {
    setPhase("creating");
    setErrorMessage(null);

    try {
      let colorHints: string[] = [];
      if (entry.photo?.photoId) {
        const photo = await getPhoto(entryId);
        if (photo?.blob) {
          colorHints = await extractPhotoColorHints(photo.blob);
        }
      }

      const signals = buildAtmosphereSignals(entry, colorHints);
      const style = choice.style;
      const prompt = buildAtmospherePrompt(style, signals);
      const { blob, source, width, height } = await requestAtmosphereImage(prompt, style, signals);

      await saveAtmosphereImage(entryId, blob, { width, height });
      const meta = buildAtmosphereMeta(
        entryId,
        style,
        prompt,
        source,
        width,
        height,
        blob.size,
        choice.emotionalLabel,
      );
      persistMeta(meta);
      trackAtmosphereCreated(entryId, style, source);
      setExpanded(false);
      setPhase("saved");
      window.setTimeout(() => setPhase("idle"), 2400);
    } catch (error) {
      setPhase("error");
      setErrorMessage(error instanceof Error ? error.message : "Visual echo could not be created.");
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
      setErrorMessage(error instanceof Error ? error.message : "Visual echo could not be removed.");
    }
  };

  if (collapsed && !hasAtmosphere) return null;

  if (hasAtmosphere && previewUrl) {
    return (
      <section className="space-y-3">
        <figure className="relative overflow-hidden rounded-2xl border border-white/[0.05]">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={previewUrl}
            alt=""
            className="max-h-64 w-full object-cover object-center opacity-90 sm:max-h-72"
          />
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="absolute right-2 top-2 bg-black/35 text-zinc-300 hover:bg-black/50"
            disabled={busy}
            onClick={() => void removeAtmosphere()}
          >
            <Trash2 className="h-4 w-4" />
            Remove
          </Button>
        </figure>
        <p className="text-xs text-zinc-600">{ATMOSPHERE_SECTION_TITLE}</p>
        <p className="text-xs text-zinc-700">{ATMOSPHERE_SECTION_DISCLAIMER}</p>
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
          {ATMOSPHERE_EXPAND_LABEL}
        </Button>
      </section>
    );
  }

  return (
    <section className="space-y-5 sm:space-y-6">
      <div className="space-y-2">
        <p className="text-sm text-zinc-400">{ATMOSPHERE_SECTION_TITLE}</p>
        {contextLine ? (
          <p className="text-sm leading-relaxed text-zinc-500">{contextLine}</p>
        ) : null}
        <p className="text-xs leading-relaxed text-zinc-600">{ATMOSPHERE_SECTION_DISCLAIMER}</p>
      </div>

      {picker && rotatedAlternate ? (
        <div className="space-y-3">
          <AtmosphereChoiceCard
            choice={picker.primary}
            variant="primary"
            disabled={busy}
            onSelect={() => void createAtmosphere(picker.primary)}
          />
          <AtmosphereChoiceCard
            choice={rotatedAlternate}
            variant="alternate"
            disabled={busy}
            onSelect={() => void createAtmosphere(rotatedAlternate)}
          />
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="text-zinc-500 hover:text-zinc-300"
          disabled={busy || !picker}
          onClick={() => {
            if (!picker) return;
            setRotateIndex((prev) => prev + 1);
          }}
        >
          <RefreshCw className="h-3.5 w-3.5" />
          {busy ? "Creating…" : ATMOSPHERE_GENERATE_ANOTHER}
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="text-zinc-600 hover:text-zinc-400"
          disabled={busy}
          onClick={() => setExpanded(false)}
        >
          Cancel
        </Button>
      </div>

      {phase === "saved" ? (
        <p className="text-xs text-zinc-500" aria-live="polite">
          Visual echo saved with this reflection.
        </p>
      ) : null}

      {phase === "error" && errorMessage ? (
        <p className="text-xs text-amber-200/90">{errorMessage}</p>
      ) : null}
    </section>
  );
}
