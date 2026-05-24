import type { VisualTone } from "@/types/personalization";

const TONE_KEY = "voicememory_visual_tone";
const AUTO_TONE_KEY = "voicememory_auto_time_tone";

export const VISUAL_TONE_OPTIONS: Array<{ id: VisualTone; label: string; detail: string }> = [
  { id: "deep-dark", label: "Deep dark", detail: "Current default — quiet and focused" },
  { id: "soft-dark", label: "Soft dark", detail: "Slightly lighter, less visual weight" },
  { id: "dusk", label: "Dusk", detail: "Warm dark with muted violet undertones" },
  { id: "morning", label: "Morning", detail: "Soft warm light for daytime" },
  { id: "warm-light", label: "Warm light", detail: "Calm parchment tones — never bright" },
];

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getStoredVisualTone(): VisualTone {
  if (!isBrowser()) return "deep-dark";
  const stored = localStorage.getItem(TONE_KEY);
  if (stored && VISUAL_TONE_OPTIONS.some((o) => o.id === stored)) {
    return stored as VisualTone;
  }
  return "deep-dark";
}

export function setStoredVisualTone(tone: VisualTone): void {
  if (!isBrowser()) return;
  localStorage.setItem(TONE_KEY, tone);
  window.dispatchEvent(new CustomEvent("voicememory:visual-tone"));
}

export function isAutoTimeOfDayToneEnabled(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(AUTO_TONE_KEY) === "1";
}

export function setAutoTimeOfDayToneEnabled(enabled: boolean): void {
  if (!isBrowser()) return;
  if (enabled) {
    localStorage.setItem(AUTO_TONE_KEY, "1");
  } else {
    localStorage.removeItem(AUTO_TONE_KEY);
  }
  window.dispatchEvent(new CustomEvent("voicememory:visual-tone"));
}

export function toneForTimeOfDay(date = new Date()): VisualTone {
  const hour = date.getHours();
  if (hour >= 5 && hour < 11) return "morning";
  if (hour >= 17 && hour < 21) return "dusk";
  if (hour >= 21 || hour < 5) return "soft-dark";
  return "warm-light";
}

/** Resolved tone — manual choice unless automatic time-of-day is on. */
export function resolveActiveVisualTone(): VisualTone {
  if (isAutoTimeOfDayToneEnabled()) return toneForTimeOfDay();
  return getStoredVisualTone();
}

export function applyVisualToneToDocument(tone: VisualTone = resolveActiveVisualTone()): void {
  if (!isBrowser()) return;
  document.documentElement.dataset.tone = tone;
  const meta = document.querySelector('meta[name="theme-color"]');
  const colors: Record<VisualTone, string> = {
    "deep-dark": "#09090b",
    "soft-dark": "#141418",
    dusk: "#15121a",
    morning: "#f3efe8",
    "warm-light": "#ede8df",
  };
  if (meta) meta.setAttribute("content", colors[tone]);
}
