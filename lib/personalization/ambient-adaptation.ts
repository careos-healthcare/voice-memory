import {
  getStoredVisualTone,
  isAutoTimeOfDayToneEnabled,
  toneForTimeOfDay,
} from "@/lib/personalization/visual-tone";
import {
  trackContrastSoftened,
  trackToneAutoChanged,
} from "@/lib/personalization/ambient-observation";
import type { JournalEntry } from "@/types/journal";
import type {
  AmbientAdaptationResolution,
  AmbientPageContext,
  ContrastComfort,
  WarmthPreference,
} from "@/types/ambient-adaptation";
import type { VisualTone } from "@/types/personalization";

const AMBIENT_ENABLED_KEY = "voicememory_ambient_adaptation_enabled";
const WARMTH_KEY = "voicememory_ambient_warmth";
const CONTRAST_KEY = "voicememory_ambient_contrast";
const SESSION_DAY_KEY = "voicememory_ambient_last_session_day";
const SESSION_STATS_KEY = "voicememory_ambient_session_stats";

const LONG_REREAD_DWELL_MS = 3 * 60 * 1000;
const LONG_REREAD_VIEWS = 3;
const HEAVY_INTENSITY = 7;

const DARK_TONES = new Set<VisualTone>(["deep-dark", "soft-dark", "dusk"]);

interface SessionStats {
  startedAt: string;
  entryViews: number;
  totalDwellMs: number;
  seenEntryIds: string[];
}

let pageContext: AmbientPageContext = {};
let lastAppliedTone: VisualTone | null = null;
let lastAppliedContrast: ContrastComfort | null = null;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function dispatchAmbientChange(): void {
  if (!isBrowser()) return;
  window.dispatchEvent(new CustomEvent("voicememory:ambient-adaptation"));
}

export function prefersReducedMotion(): boolean {
  if (!isBrowser()) return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export function isAmbientAdaptationEnabled(): boolean {
  if (!isBrowser()) return true;
  return localStorage.getItem(AMBIENT_ENABLED_KEY) !== "0";
}

export function setAmbientAdaptationEnabled(enabled: boolean): void {
  if (!isBrowser()) return;
  localStorage.setItem(AMBIENT_ENABLED_KEY, enabled ? "1" : "0");
  dispatchAmbientChange();
}

export function getWarmthPreference(): WarmthPreference {
  if (!isBrowser()) return "balanced";
  const stored = localStorage.getItem(WARMTH_KEY);
  if (stored === "cooler" || stored === "warmer") return stored;
  return "balanced";
}

export function setWarmthPreference(value: WarmthPreference): void {
  if (!isBrowser()) return;
  localStorage.setItem(WARMTH_KEY, value);
  dispatchAmbientChange();
}

export function getContrastComfort(): ContrastComfort {
  if (!isBrowser()) return "standard";
  return localStorage.getItem(CONTRAST_KEY) === "softer" ? "softer" : "standard";
}

export function setContrastComfort(value: ContrastComfort): void {
  if (!isBrowser()) return;
  localStorage.setItem(CONTRAST_KEY, value);
  dispatchAmbientChange();
}

function readSessionStats(): SessionStats {
  if (!isBrowser()) {
    return { startedAt: new Date().toISOString(), entryViews: 0, totalDwellMs: 0, seenEntryIds: [] };
  }
  try {
    const raw = sessionStorage.getItem(SESSION_STATS_KEY);
    if (!raw) {
      return {
        startedAt: new Date().toISOString(),
        entryViews: 0,
        totalDwellMs: 0,
        seenEntryIds: [],
      };
    }
    const parsed = JSON.parse(raw) as Partial<SessionStats>;
    return {
      startedAt: parsed.startedAt ?? new Date().toISOString(),
      entryViews: parsed.entryViews ?? 0,
      totalDwellMs: parsed.totalDwellMs ?? 0,
      seenEntryIds: Array.isArray(parsed.seenEntryIds) ? parsed.seenEntryIds : [],
    };
  } catch {
    return {
      startedAt: new Date().toISOString(),
      entryViews: 0,
      totalDwellMs: 0,
      seenEntryIds: [],
    };
  }
}

function writeSessionStats(stats: SessionStats): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(SESSION_STATS_KEY, JSON.stringify(stats));
}

export function markSessionDay(): void {
  if (!isBrowser()) return;
  const today = new Date().toDateString();
  localStorage.setItem(SESSION_DAY_KEY, today);
}

export function isFirstSessionOfDay(now = new Date()): boolean {
  if (!isBrowser()) return false;
  const today = now.toDateString();
  const last = localStorage.getItem(SESSION_DAY_KEY);
  return last !== today;
}

export function recordAmbientSessionActivity(entryId: string, dwellMs = 0): void {
  if (!isBrowser()) return;
  const stats = readSessionStats();
  if (!stats.seenEntryIds.includes(entryId)) {
    stats.seenEntryIds.push(entryId);
    stats.entryViews += 1;
  }
  stats.totalDwellMs += Math.max(0, dwellMs);
  writeSessionStats(stats);
  markSessionDay();
  dispatchAmbientChange();
}

export function isLongRereadSession(): boolean {
  const stats = readSessionStats();
  return (
    stats.totalDwellMs >= LONG_REREAD_DWELL_MS || stats.entryViews >= LONG_REREAD_VIEWS
  );
}

export function setAmbientPageContext(context: Partial<AmbientPageContext>): void {
  pageContext = { ...pageContext, ...context };
  dispatchAmbientChange();
}

export function clearAmbientPageContext(): void {
  pageContext = {};
  dispatchAmbientChange();
}

export function getAmbientPageContext(): AmbientPageContext {
  return { ...pageContext };
}

export function isHeavyEntry(entry: JournalEntry | undefined): boolean {
  if (!entry) return false;
  return entry.reflection.emotionalIntensity >= HEAVY_INTENSITY;
}

function warmthAfterMidnight(hour: number, preference: WarmthPreference): WarmthPreference {
  if (hour >= 0 && hour < 5) {
    if (preference === "cooler") return "balanced";
    return "warmer";
  }
  return preference;
}

function toneShiftForAmbient(
  baseTone: VisualTone,
  now: Date,
  firstSession: boolean,
  warmth: WarmthPreference,
): VisualTone {
  const hour = now.getHours();

  if (firstSession && hour >= 5 && hour < 11 && DARK_TONES.has(baseTone)) {
    return "morning";
  }

  if (hour >= 0 && hour < 5 && DARK_TONES.has(baseTone)) {
    if (warmth === "warmer" || warmth === "balanced") return "dusk";
    return "soft-dark";
  }

  if (warmth === "warmer" && baseTone === "deep-dark") return "soft-dark";
  if (warmth === "warmer" && baseTone === "soft-dark") return "dusk";
  if (warmth === "cooler" && baseTone === "dusk") return "soft-dark";

  return baseTone;
}

function resolveWarmth(
  preference: WarmthPreference,
  now: Date,
  firstSession: boolean,
): WarmthPreference {
  let warmth = warmthAfterMidnight(now.getHours(), preference);
  if (firstSession && now.getHours() >= 5 && now.getHours() < 11 && warmth !== "cooler") {
    warmth = "warmer";
  }
  return warmth;
}

function resolveContrast(
  preference: ContrastComfort,
  longReread: boolean,
): ContrastComfort {
  if (longReread) return "softer";
  return preference;
}

/** Subtle visual adaptation — no gimmicks, no animated backgrounds. */
export function resolveAmbientAdaptation(
  baseTone: VisualTone,
  now = new Date(),
): AmbientAdaptationResolution {
  const enabled = isAmbientAdaptationEnabled();
  const reducedMotion = prefersReducedMotion();
  const warmthPreference = getWarmthPreference();
  const contrastPreference = getContrastComfort();
  const firstSession = isFirstSessionOfDay(now);
  const longReread = isLongRereadSession();
  const context = getAmbientPageContext();

  if (!enabled) {
    return {
      enabled: false,
      baseTone,
      resolvedTone: baseTone,
      warmth: warmthPreference,
      contrast: contrastPreference,
      saturation: "normal",
      background: "normal",
      longRereadSession: longReread,
      firstSessionOfDay: firstSession,
      reducedMotion,
    };
  }

  const warmth = resolveWarmth(warmthPreference, now, firstSession);
  const contrast = resolveContrast(contrastPreference, longReread);
  const saturation = context.heavyEntry ? "quiet" : "normal";
  const background = context.isRevisit ? "quiet" : "normal";

  let resolvedTone = baseTone;
  if (!reducedMotion) {
    resolvedTone = toneShiftForAmbient(baseTone, now, firstSession, warmth);
  }

  return {
    enabled: true,
    baseTone,
    resolvedTone,
    warmth,
    contrast,
    saturation,
    background,
    longRereadSession: longReread,
    firstSessionOfDay: firstSession,
    reducedMotion,
  };
}

export function resolveFullyAdaptedVisualTone(now = new Date()): VisualTone {
  const autoTone = isAutoTimeOfDayToneEnabled();
  const baseTone = autoTone ? toneForTimeOfDay(now) : getStoredVisualTone();
  const ambient = resolveAmbientAdaptation(baseTone, now);
  return ambient.resolvedTone;
}

export function applyAmbientAdaptationToDocument(
  resolution: AmbientAdaptationResolution = resolveAmbientAdaptation(
    isAutoTimeOfDayToneEnabled() ? toneForTimeOfDay() : getStoredVisualTone(),
  ),
): void {
  if (!isBrowser()) return;

  const root = document.documentElement;

  if (!resolution.enabled) {
    delete root.dataset.ambientWarmth;
    delete root.dataset.ambientContrast;
    delete root.dataset.ambientSaturation;
    delete root.dataset.ambientBg;
    delete root.dataset.ambientReduced;
    return;
  }

  root.dataset.ambientWarmth = resolution.warmth;
  root.dataset.ambientContrast = resolution.contrast;
  root.dataset.ambientSaturation = resolution.saturation;
  root.dataset.ambientBg = resolution.background;
  if (resolution.reducedMotion) {
    root.dataset.ambientReduced = "true";
  } else {
    delete root.dataset.ambientReduced;
  }

  if (resolution.resolvedTone !== lastAppliedTone && resolution.resolvedTone !== resolution.baseTone) {
    trackToneAutoChanged(resolution.baseTone, resolution.resolvedTone, "ambient_adaptation");
    lastAppliedTone = resolution.resolvedTone;
  }

  if (
    resolution.contrast === "softer" &&
    lastAppliedContrast !== "softer"
  ) {
    const reason = resolution.longRereadSession ? "long_reread" : "preference";
    trackContrastSoftened(reason);
    lastAppliedContrast = "softer";
  } else if (resolution.contrast === "standard") {
    lastAppliedContrast = "standard";
  }
}

export function buildAmbientSettingsSnapshot() {
  return {
    ambientAdaptationEnabled: isAmbientAdaptationEnabled(),
    warmthPreference: getWarmthPreference(),
    contrastComfort: getContrastComfort(),
  };
}
