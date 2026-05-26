import { classifyEmotionalCaptureState, getCaptureRouting } from "@/lib/capture/emotional-state-routing";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { ReflexCaptureContext } from "@/lib/reflex/reflex-context";
import type { RecordReturnContext } from "@/types/record-return";

export type ZeroStateRecorderMode = "mic_only" | "one_line_mic" | "quote_first";

export interface ZeroStateRecorderInput {
  route?: "record" | "home" | "return";
  recordReturn?: RecordReturnContext | null;
  clarityRecord?: ClarityRecordContext | null;
  reflexCapture?: ReflexCaptureContext | null;
  preserveQuote?: string | null;
}

export function shouldUseZeroStateRecorder(input?: ZeroStateRecorderInput): boolean {
  if (input?.route === "record") return true;
  if (input?.recordReturn || input?.clarityRecord || input?.reflexCapture) return true;
  if (input?.preserveQuote?.trim()) return true;
  const state = classifyEmotionalCaptureState();
  return state !== "neutral";
}

export function getZeroStateRecorderMode(
  input: ZeroStateRecorderInput = {},
): ZeroStateRecorderMode {
  const routing = getCaptureRouting({
    recordReturn: input.recordReturn,
    clarityRecord: input.clarityRecord,
    reflexCapture: input.reflexCapture,
    preserveQuote: input.preserveQuote,
  });
  if (routing.mode === "mic_only") return "mic_only";
  if (routing.mode === "quote_first") return "quote_first";
  return "one_line_mic";
}

export function getZeroStateRecorderLine(
  input: ZeroStateRecorderInput = {},
): string | null {
  const routing = getCaptureRouting({
    recordReturn: input.recordReturn,
    clarityRecord: input.clarityRecord,
    reflexCapture: input.reflexCapture,
    preserveQuote: input.preserveQuote,
  });
  return routing.preSpeechLine;
}

export function shouldAutoStartZeroStateRecorder(
  input: ZeroStateRecorderInput = {},
): boolean {
  return getCaptureRouting({
    recordReturn: input.recordReturn,
    clarityRecord: input.clarityRecord,
    reflexCapture: input.reflexCapture,
    preserveQuote: input.preserveQuote,
  }).autoStart;
}
