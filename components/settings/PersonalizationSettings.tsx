"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  isAutoTimeOfDayToneEnabled,
  setAutoTimeOfDayToneEnabled,
  setStoredVisualTone,
  getStoredVisualTone,
  VISUAL_TONE_OPTIONS,
} from "@/lib/personalization/visual-tone";
import type { VisualTone } from "@/types/personalization";
import {
  isPhotoAttachmentEnabled,
  setPhotoAttachmentEnabled,
} from "@/lib/personalization/photo-preferences";

export function PersonalizationSettings() {
  const [tone, setTone] = useState<VisualTone>("deep-dark");
  const [autoTone, setAutoTone] = useState(false);
  const [photosEnabled, setPhotosEnabled] = useState(true);

  useEffect(() => {
    setTone(getStoredVisualTone());
    setAutoTone(isAutoTimeOfDayToneEnabled());
    setPhotosEnabled(isPhotoAttachmentEnabled());
  }, []);

  return (
    <div className="space-y-6">
      <div className="space-y-3">
        <p className="text-sm font-medium text-zinc-300">Visual tone</p>
        <p className="text-sm text-zinc-400">
          Calm, minimal palettes — no bright themes or decorative styling.
        </p>
        <div className="grid gap-2 sm:grid-cols-2">
          {VISUAL_TONE_OPTIONS.map((option) => (
            <Button
              key={option.id}
              type="button"
              variant={tone === option.id && !autoTone ? "default" : "secondary"}
              size="sm"
              className="h-auto flex-col items-start gap-1 px-3 py-3 text-left"
              disabled={autoTone}
              onClick={() => {
                setStoredVisualTone(option.id);
                setTone(option.id);
              }}
            >
              <span className="text-sm">{option.label}</span>
              <span className="text-xs font-normal text-zinc-500">{option.detail}</span>
            </Button>
          ))}
        </div>
      </div>

      <div className="space-y-3 border-t border-white/5 pt-6">
        <p className="text-sm font-medium text-zinc-300">Automatic time-of-day tone</p>
        <p className="text-sm text-zinc-400">
          Morning uses warmer light, evening uses dusk, night uses soft dark.
        </p>
        <Button
          type="button"
          variant={autoTone ? "default" : "secondary"}
          size="sm"
          onClick={() => {
            const next = !autoTone;
            setAutoTimeOfDayToneEnabled(next);
            setAutoTone(next);
          }}
        >
          {autoTone ? "Automatic tone on" : "Enable automatic tone"}
        </Button>
      </div>

      <div className="space-y-3 border-t border-white/5 pt-6">
        <p className="text-sm font-medium text-zinc-300">Photo attachments</p>
        <p className="text-sm text-zinc-400">
          One optional photo per reflection — stored on this device only. No feed, filters, or
          sharing prompts.
        </p>
        <Button
          type="button"
          variant={photosEnabled ? "default" : "secondary"}
          size="sm"
          onClick={() => {
            const next = !photosEnabled;
            setPhotoAttachmentEnabled(next);
            setPhotosEnabled(next);
          }}
        >
          {photosEnabled ? "Photos enabled" : "Enable photos"}
        </Button>
      </div>
    </div>
  );
}
