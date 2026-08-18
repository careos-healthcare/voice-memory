export type WarmthPreference = "cooler" | "balanced" | "warmer";
export type ContrastComfort = "standard" | "softer";

export interface AmbientPageContext {
  isRevisit?: boolean;
  heavyEntry?: boolean;
}

export interface AmbientAdaptationResolution {
  enabled: boolean;
  baseTone: import("@/types/personalization").VisualTone;
  resolvedTone: import("@/types/personalization").VisualTone;
  warmth: WarmthPreference;
  contrast: ContrastComfort;
  saturation: "normal" | "quiet";
  background: "normal" | "quiet";
  longRereadSession: boolean;
  firstSessionOfDay: boolean;
  reducedMotion: boolean;
}
