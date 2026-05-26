import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import { buildReadVsSpeakRisk } from "@/lib/reflex/read-vs-speak";
import { shouldActivateReflexSilenceFirst } from "@/lib/reflex/open-without-record";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";

export const HESITATION_EVENTS = {
  detected: "hesitation_before_speech",
  silenceBeforeSpeech: "silence_before_speech",
  forceDirectMic: "force_direct_mic_next_session",
} as const;

const FORCE_DIRECT_MIC_KEY = "voicememory_force_direct_mic";
const HESITATION_COUNT_KEY = "voicememory_hesitation_count";
const MIC_VISIBLE_AT_KEY = "voicememory_hesitation_mic_at";
const SILENCE_BEFORE_SPEECH_KEY = "voicememory_silence_before_speech_ms";

const HESITATION_THRESHOLD_MS = 12_000;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function median(values: number[]): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)] ?? null;
}

export function markMicVisibleForHesitation(): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  sessionStorage.setItem(MIC_VISIBLE_AT_KEY, String(Date.now()));
}

export function clearHesitationWatch(): void {
  if (!isBrowser()) return;
  sessionStorage.removeItem(MIC_VISIBLE_AT_KEY);
}

export function markSpeechStartedAfterHesitation(): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  const micAt = Number(sessionStorage.getItem(MIC_VISIBLE_AT_KEY) ?? "0");
  if (micAt <= 0) return;
  const gapMs = Date.now() - micAt;
  sessionStorage.removeItem(MIC_VISIBLE_AT_KEY);
  if (gapMs < 1500) return;

  trackLocalEvent(HESITATION_EVENTS.silenceBeforeSpeech, { ms: String(gapMs) });
  sessionStorage.setItem(SILENCE_BEFORE_SPEECH_KEY, String(gapMs));

  if (gapMs >= HESITATION_THRESHOLD_MS) {
    trackLocalEvent(HESITATION_EVENTS.detected, { ms: String(gapMs) });
    const count = Number(localStorage.getItem(HESITATION_COUNT_KEY) ?? "0") + 1;
    localStorage.setItem(HESITATION_COUNT_KEY, String(count));
    if (count >= 2) {
      localStorage.setItem(FORCE_DIRECT_MIC_KEY, "1");
      trackLocalEvent(HESITATION_EVENTS.forceDirectMic, { reason: "hesitation_repeat" });
    }
  }
}

function repeatedOpenWithoutSpeaking(): boolean {
  return shouldActivateReflexSilenceFirst();
}

function repeatedContinuityReading(): boolean {
  const risk = buildReadVsSpeakRisk();
  return risk.passiveReadingLikely || risk.consumableContinuityRisk;
}

/** Next session: skip continuity stack, open mic-first. */
export function shouldForceDirectMicNextSession(): boolean {
  if (!isBrowser()) return false;
  if (localStorage.getItem(FORCE_DIRECT_MIC_KEY) === "1") return true;
  if (repeatedOpenWithoutSpeaking() && repeatedContinuityReading()) {
    localStorage.setItem(FORCE_DIRECT_MIC_KEY, "1");
    trackLocalEvent(HESITATION_EVENTS.forceDirectMic, {
      reason: "reopen_and_read_without_speak",
    });
    return true;
  }
  if (repeatedOpenWithoutSpeaking()) return true;
  return false;
}

export function shouldSuppressContinuityEntirely(): boolean {
  return shouldForceDirectMicNextSession();
}

export function clearForceDirectMicAfterCapture(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(FORCE_DIRECT_MIC_KEY);
  localStorage.setItem(HESITATION_COUNT_KEY, "0");
}

export function buildHesitationReport(): {
  medianHesitationMs: number | null;
  medianSilenceBeforeSpeechMs: number | null;
  hesitationEvents: number;
  forceDirectMicActive: boolean;
} {
  if (!isBrowser()) {
    return {
      medianHesitationMs: null,
      medianSilenceBeforeSpeechMs: null,
      hesitationEvents: 0,
      forceDirectMicActive: false,
    };
  }

  const events = readLocalEvents();
  const hesitationMs = events
    .filter((e) => e.name === HESITATION_EVENTS.detected)
    .map((e) => Number(e.meta?.ms ?? "0"))
    .filter((n) => n > 0);
  const silenceMs = events
    .filter((e) => e.name === HESITATION_EVENTS.silenceBeforeSpeech)
    .map((e) => Number(e.meta?.ms ?? "0"))
    .filter((n) => n > 0);

  return {
    medianHesitationMs: median(hesitationMs),
    medianSilenceBeforeSpeechMs: median(silenceMs),
    hesitationEvents: hesitationMs.length,
    forceDirectMicActive: shouldForceDirectMicNextSession(),
  };
}
