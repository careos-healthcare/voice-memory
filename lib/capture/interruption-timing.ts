import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";
import { classifyEmotionalCaptureState } from "@/lib/capture/emotional-state-routing";
import { buildReadVsSpeakRisk } from "@/lib/reflex/read-vs-speak";
import { getResurfacingFatigueRecords } from "@/lib/resurfacing/resurfacing-fatigue";
import { getRecentResurfacingModes } from "@/lib/resurfacing/return-modes";
import { shouldReduceResurfacingFrequency } from "@/lib/resurfacing/resurfacing-frequency";
import type {
  InterruptionMode,
  InterruptionTimingMetrics,
  InterruptionTimingReport,
} from "@/types/interruption-timing";

export const INTERRUPTION_EVENTS = {
  shown: "interruption_shown",
  suppressed: "interruption_suppressed",
  ledToRecording: "interruption_led_to_recording",
  ledToReading: "interruption_led_to_reading",
  silenceChosen: "silence_chosen_over_resurfacing",
} as const;

const STORE_KEY = "voicememory_interruption_timing";

interface InterruptionStore {
  quoteFirstWins: number;
  contradictionWins: number;
  silenceWins: number;
  ignoredStreak: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readStore(): InterruptionStore {
  if (!isBrowser()) {
    return { quoteFirstWins: 0, contradictionWins: 0, silenceWins: 0, ignoredStreak: 0 };
  }
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return { quoteFirstWins: 0, contradictionWins: 0, silenceWins: 0, ignoredStreak: 0 };
    const parsed = JSON.parse(raw) as Partial<InterruptionStore>;
    return {
      quoteFirstWins: parsed.quoteFirstWins ?? 0,
      contradictionWins: parsed.contradictionWins ?? 0,
      silenceWins: parsed.silenceWins ?? 0,
      ignoredStreak: parsed.ignoredStreak ?? 0,
    };
  } catch {
    return { quoteFirstWins: 0, contradictionWins: 0, silenceWins: 0, ignoredStreak: 0 };
  }
}

function writeStore(store: InterruptionStore): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  localStorage.setItem(STORE_KEY, JSON.stringify(store));
}

function buildMetrics(): InterruptionTimingMetrics {
  const events = readLocalEvents();
  return {
    shown: events.filter((e) => e.name === INTERRUPTION_EVENTS.shown).length,
    suppressed: events.filter((e) => e.name === INTERRUPTION_EVENTS.suppressed).length,
    ledToRecording: events.filter((e) => e.name === INTERRUPTION_EVENTS.ledToRecording).length,
    ledToReading: events.filter((e) => e.name === INTERRUPTION_EVENTS.ledToReading).length,
    silenceChosen: events.filter((e) => e.name === INTERRUPTION_EVENTS.silenceChosen).length,
  };
}

export function trackInterruptionEvent(
  name: (typeof INTERRUPTION_EVENTS)[keyof typeof INTERRUPTION_EVENTS],
  meta?: Record<string, string>,
): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  trackLocalEvent(name, meta);
}

export function shouldStaySilent(): boolean {
  if (shouldReduceResurfacingFrequency()) return true;
  const readRisk = buildReadVsSpeakRisk();
  if (readRisk.passiveReadingLikely) return true;
  const state = classifyEmotionalCaptureState();
  if (state === "exhausted" || state === "over_reading" || state === "distressed") {
    return true;
  }
  const fatigue = getResurfacingFatigueRecords();
  const ignoredHeavy = fatigue.filter(
    (row) => row.ignoredCount >= 2 || row.openedWithoutReflection >= 2,
  ).length;
  if (ignoredHeavy >= 2) return true;
  const store = readStore();
  if (store.ignoredStreak >= 3) return true;
  return false;
}

export function bestInterruptionMode(): InterruptionMode {
  if (shouldStaySilent()) return "silence";
  const store = readStore();
  const recentModes = getRecentResurfacingModes();
  if (recentModes.includes("contradiction")) return "contradiction";
  if (store.quoteFirstWins >= store.contradictionWins) return "quote_first";
  if (recentModes.includes("silence_gap")) return "change";
  return "one_line";
}

export function shouldInterruptNow(): boolean {
  if (isSideEffectBlocked()) return false;
  if (shouldStaySilent()) {
    trackInterruptionEvent(INTERRUPTION_EVENTS.suppressed, { reason: "stay_silent" });
    trackInterruptionEvent(INTERRUPTION_EVENTS.silenceChosen);
    return false;
  }
  const metrics = buildMetrics();
  if (metrics.ledToReading > metrics.ledToRecording + 2) {
    trackInterruptionEvent(INTERRUPTION_EVENTS.suppressed, { reason: "reading_risk" });
    return false;
  }
  return true;
}

export function recordInterruptionOutcome(
  outcome: "recording" | "reading" | "ignored",
  mode?: InterruptionMode,
): void {
  const store = readStore();
  if (outcome === "recording") {
    trackInterruptionEvent(INTERRUPTION_EVENTS.ledToRecording, { mode: mode ?? "" });
    store.ignoredStreak = 0;
    if (mode === "quote_first") store.quoteFirstWins += 1;
    if (mode === "contradiction" || mode === "change") store.contradictionWins += 1;
  } else if (outcome === "reading") {
    trackInterruptionEvent(INTERRUPTION_EVENTS.ledToReading, { mode: mode ?? "" });
    store.ignoredStreak += 1;
  } else {
    store.ignoredStreak += 1;
  }
  if (mode === "silence") store.silenceWins += 1;
  writeStore(store);
}

export function recordInterruptionShown(mode: InterruptionMode): void {
  trackInterruptionEvent(INTERRUPTION_EVENTS.shown, { mode });
}

export function buildInterruptionTimingReport(): InterruptionTimingReport {
  const metrics = buildMetrics();
  const staySilent = shouldStaySilent();
  const interrupt = shouldInterruptNow();
  return {
    metrics,
    shouldInterruptNow: interrupt,
    shouldStaySilent: staySilent,
    bestMode: bestInterruptionMode(),
    plain: staySilent
      ? "Silence chosen — weak resurfacing suppressed."
      : interrupt
        ? `Interrupt allowed — best mode ${bestInterruptionMode()}.`
        : "Interrupt suppressed — reading risk or fatigue.",
  };
}
