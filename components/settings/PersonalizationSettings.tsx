"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  isAmbientAdaptationEnabled,
  setAmbientAdaptationEnabled,
  getWarmthPreference,
  setWarmthPreference,
  getContrastComfort,
  setContrastComfort,
} from "@/lib/personalization/ambient-adaptation";
import { trackAmbientModeEnabled } from "@/lib/personalization/ambient-observation";
import {
  isAutoTimeOfDayToneEnabled,
  setAutoTimeOfDayToneEnabled,
  setStoredVisualTone,
  getStoredVisualTone,
  VISUAL_TONE_OPTIONS,
} from "@/lib/personalization/visual-tone";
import type { VisualTone } from "@/types/personalization";
import type { ContrastComfort, WarmthPreference } from "@/types/ambient-adaptation";
import {
  isPhotoAttachmentEnabled,
  setPhotoAttachmentEnabled,
} from "@/lib/personalization/photo-preferences";
import {
  isSilenceIntelligenceEnabled,
  setSilenceIntelligenceEnabled,
} from "@/lib/restraint/silence-intelligence";

const WARMTH_OPTIONS: Array<{ id: WarmthPreference; label: string }> = [
  { id: "cooler", label: "Cooler" },
  { id: "balanced", label: "Balanced" },
  { id: "warmer", label: "Warmer" },
];

const CONTRAST_OPTIONS: Array<{ id: ContrastComfort; label: string }> = [
  { id: "standard", label: "Standard" },
  { id: "softer", label: "Softer" },
];

export function PersonalizationSettings() {
  const [tone, setTone] = useState<VisualTone>("deep-dark");
  const [autoTone, setAutoTone] = useState(false);
  const [photosEnabled, setPhotosEnabled] = useState(true);
  const [ambientEnabled, setAmbientEnabled] = useState(true);
  const [warmth, setWarmth] = useState<WarmthPreference>("balanced");
  const [contrast, setContrast] = useState<ContrastComfort>("standard");
  const [silenceIntelligence, setSilenceIntelligence] = useState(true);

  useEffect(() => {
    setTone(getStoredVisualTone());
    setAutoTone(isAutoTimeOfDayToneEnabled());
    setPhotosEnabled(isPhotoAttachmentEnabled());
    setAmbientEnabled(isAmbientAdaptationEnabled());
    setWarmth(getWarmthPreference());
    setContrast(getContrastComfort());
    setSilenceIntelligence(isSilenceIntelligenceEnabled());
  }, []);

  return (
    <div className="space-y-6">
      <div className="space-y-3">
        <p className="text-sm font-medium text-zinc-300">Visual tone</p>
        <p className="text-sm text-muted">
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
              <span className="text-xs font-normal text-muted">{option.detail}</span>
            </Button>
          ))}
        </div>
      </div>

      <div className="space-y-3 border-t border-white/5 pt-6">
        <p className="text-sm font-medium text-zinc-300">Automatic time-of-day tone</p>
        <p className="text-sm text-muted">
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
        <p className="text-sm font-medium text-zinc-300">Ambient adaptation</p>
        <p className="text-sm text-muted">
          Subtle shifts for long rereads, revisits, and time of day — never decorative or
          mood-reactive.
        </p>
        <Button
          type="button"
          variant={ambientEnabled ? "default" : "secondary"}
          size="sm"
          onClick={() => {
            const next = !ambientEnabled;
            setAmbientAdaptationEnabled(next);
            setAmbientEnabled(next);
            if (next) trackAmbientModeEnabled();
          }}
        >
          {ambientEnabled ? "Ambient adaptation on" : "Enable ambient adaptation"}
        </Button>
      </div>

      <div className="space-y-3 border-t border-white/5 pt-6">
        <p className="text-sm font-medium text-zinc-300">Warmth preference</p>
        <p className="text-sm text-muted">How warm the interface should feel over a session.</p>
        <div className="flex flex-wrap gap-2">
          {WARMTH_OPTIONS.map((option) => (
            <Button
              key={option.id}
              type="button"
              variant={warmth === option.id ? "default" : "secondary"}
              size="sm"
              disabled={!ambientEnabled}
              onClick={() => {
                setWarmthPreference(option.id);
                setWarmth(option.id);
              }}
            >
              {option.label}
            </Button>
          ))}
        </div>
      </div>

      <div className="space-y-3 border-t border-white/5 pt-6">
        <p className="text-sm font-medium text-zinc-300">Contrast comfort</p>
        <p className="text-sm text-muted">
          Softer contrast during long reading sessions or when you prefer less visual weight.
        </p>
        <div className="flex flex-wrap gap-2">
          {CONTRAST_OPTIONS.map((option) => (
            <Button
              key={option.id}
              type="button"
              variant={contrast === option.id ? "default" : "secondary"}
              size="sm"
              disabled={!ambientEnabled}
              onClick={() => {
                setContrastComfort(option.id);
                setContrast(option.id);
              }}
            >
              {option.label}
            </Button>
          ))}
        </div>
      </div>

      <div className="space-y-3 border-t border-white/5 pt-6">
        <p className="text-sm font-medium text-zinc-300">Quiet mode</p>
        <p className="text-sm text-muted">
          Lets the app say less for a while when callbacks are ignored, revisits feel heavy, or you
          mostly want to record. Saved entries stay visible — recording and export are never blocked.
        </p>
        <Button
          type="button"
          variant={silenceIntelligence ? "default" : "secondary"}
          size="sm"
          onClick={() => {
            const next = !silenceIntelligence;
            setSilenceIntelligenceEnabled(next);
            setSilenceIntelligence(next);
          }}
        >
          {silenceIntelligence ? "Quiet mode on" : "Enable quiet mode"}
        </Button>
      </div>

      <div className="space-y-3 border-t border-white/5 pt-6">
        <p className="text-sm font-medium text-zinc-300">Photo attachments</p>
        <p className="text-sm text-muted">
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
