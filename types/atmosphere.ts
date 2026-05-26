export type AtmosphereStyle =
  | "soft-light"
  | "rainy-window"
  | "quiet-room"
  | "dusk-field"
  | "foggy-street"
  | "morning-glow"
  | "abstract-color-field";

export type AtmosphereSource = "fallback" | "api";

/** Emotional label shown in UI — maps to an internal generation style. */
export type EmotionalAtmosphereLabel =
  | "waiting"
  | "pressure"
  | "distance"
  | "relief"
  | "restlessness"
  | "uncertainty"
  | "soft-focus"
  | "calm-after-noise"
  | "emotional-static";

/** Stored on entry for resurfacing — not shown in product UI. */
export interface AtmosphereFingerprint {
  label: string;
  emotionalLabel: EmotionalAtmosphereLabel;
  tone: string;
  paletteIntent: string;
  style: AtmosphereStyle;
  sourceEntryId: string;
  createdAt: string;
}

export interface EntryAtmosphereMeta {
  atmosphereId: string;
  style: AtmosphereStyle;
  prompt: string;
  source: AtmosphereSource;
  mimeType: string;
  width: number;
  height: number;
  byteLength?: number;
  createdAt: string;
  emotionalLabel?: EmotionalAtmosphereLabel;
  fingerprint?: AtmosphereFingerprint;
}

export interface AtmosphereSignals {
  timeOfDay: "night" | "morning" | "day" | "evening";
  weatherHint: string | null;
  toneHint: string | null;
  colorHints: string[];
}

export interface AtmosphereChoice {
  emotionalLabel: EmotionalAtmosphereLabel;
  displayLabel: string;
  style: AtmosphereStyle;
  hint: string;
  score: number;
}
