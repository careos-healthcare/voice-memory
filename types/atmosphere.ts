export type AtmosphereStyle =
  | "soft-light"
  | "rainy-window"
  | "quiet-room"
  | "dusk-field"
  | "foggy-street"
  | "morning-glow"
  | "abstract-color-field";

export type AtmosphereSource = "fallback" | "api";

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
}

export interface AtmosphereSignals {
  timeOfDay: "night" | "morning" | "day" | "evening";
  weatherHint: string | null;
  toneHint: string | null;
  colorHints: string[];
}
