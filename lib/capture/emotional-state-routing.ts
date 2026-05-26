import { buildReadVsSpeakRisk } from "@/lib/reflex/read-vs-speak";
import { shouldActivateReflexSilenceFirst } from "@/lib/reflex/open-without-record";
import { detectReflexCapture } from "@/lib/reflex/reflex-capture";
import { shouldReduceResurfacingFrequency } from "@/lib/resurfacing/resurfacing-frequency";
import { detectThinkingOutLoudSignals } from "@/lib/clarity/thinking-out-loud-signals";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { ReflexCaptureContext } from "@/lib/reflex/reflex-context";
import type { RecordReturnContext } from "@/types/record-return";

export type EmotionalCaptureState =
  | "distressed"
  | "looping"
  | "uncertain"
  | "exhausted"
  | "over_reading"
  | "neutral";

export type CaptureRoutingMode = "mic_only" | "one_line_mic" | "quote_first";

export interface CaptureRouting {
  state: EmotionalCaptureState;
  mode: CaptureRoutingMode;
  preSpeechLine: string | null;
  suppressStack: boolean;
  autoStart: boolean;
}

const RUMINATION_RE =
  /\b(i keep thinking|can't stop thinking|keeps circling|going over this again)\b/i;

/** Routing only — never shown to users. */
export function classifyEmotionalCaptureState(): EmotionalCaptureState {
  if (isSideEffectBlocked()) return "neutral";

  const readRisk = buildReadVsSpeakRisk();
  if (readRisk.passiveReadingLikely || readRisk.consumableContinuityRisk) {
    return "over_reading";
  }

  if (shouldActivateReflexSilenceFirst() || shouldReduceResurfacingFrequency()) {
    return "exhausted";
  }

  const entries = getMemoryEligibleEntries();
  const latest = entries[entries.length - 1];
  if (latest?.transcript) {
    const signals = detectThinkingOutLoudSignals(latest.transcript);
    if (signals.conflictLikely && signals.confidence >= 55) return "distressed";
    if (signals.uncertaintyLikely && signals.confidence >= 50) return "uncertain";
    if (RUMINATION_RE.test(latest.transcript)) return "looping";
  }

  const reflex = detectReflexCapture(entries);
  if (reflex.triggerType === "rumination_phrase" || reflex.triggerType === "uncertainty_repeat") {
    return "looping";
  }
  if (reflex.triggerType === "post_conflict") return "distressed";
  if (reflex.triggerType === "late_night") return "exhausted";

  return "neutral";
}

export function getCaptureRouting(input?: {
  recordReturn?: RecordReturnContext | null;
  clarityRecord?: ClarityRecordContext | null;
  reflexCapture?: ReflexCaptureContext | null;
  preserveQuote?: string | null;
}): CaptureRouting {
  const state = classifyEmotionalCaptureState();

  const quote =
    input?.preserveQuote?.trim() ||
    input?.recordReturn?.anchorQuote?.trim() ||
    input?.reflexCapture?.anchorQuote?.trim() ||
    input?.clarityRecord?.anchorSnippet?.trim() ||
    null;

  switch (state) {
    case "distressed":
      return {
        state,
        mode: "mic_only",
        preSpeechLine: null,
        suppressStack: true,
        autoStart: true,
      };
    case "exhausted":
    case "over_reading":
      return {
        state,
        mode: "mic_only",
        preSpeechLine: null,
        suppressStack: true,
        autoStart: false,
      };
    case "looping":
      return {
        state,
        mode: quote ? "quote_first" : "one_line_mic",
        preSpeechLine: quote ? `"${quote.slice(0, 100)}"` : null,
        suppressStack: true,
        autoStart: Boolean(quote),
      };
    case "uncertain":
      return {
        state,
        mode: "one_line_mic",
        preSpeechLine:
          quote?.slice(0, 120) ??
          input?.clarityRecord?.recorderPrompt?.slice(0, 120) ??
          input?.reflexCapture?.continuityLine?.slice(0, 120) ??
          null,
        suppressStack: true,
        autoStart: true,
      };
    default:
      return {
        state: "neutral",
        mode: quote ? "quote_first" : "one_line_mic",
        preSpeechLine:
          input?.reflexCapture?.continuityLine ??
          quote?.slice(0, 120) ??
          null,
        suppressStack: false,
        autoStart: Boolean(input?.recordReturn || input?.reflexCapture),
      };
  }
}
