import type { ApiUsageKind } from "@/lib/server/api-usage-store";
import {
  MAX_ATMOSPHERE_PROMPT_CHARS,
  MAX_AUDIO_BYTES,
  MAX_TRANSCRIPT_CHARS,
} from "@/lib/server/api-limits";

/** Fixed-point micro-USD (1 USD = 1_000_000). */
export type MicroUsd = number;

export const MICRO_USD_PER_DOLLAR = 1_000_000;

/** Conservative list prices — overestimate slightly for guardrails. */
const WHISPER_USD_PER_MINUTE = 0.006;
const GPT4O_MINI_INPUT_USD_PER_1M = 0.15;
const GPT4O_MINI_OUTPUT_USD_PER_1M = 0.6;
const DALLE3_STANDARD_USD_PER_IMAGE = 0.04;

const ANALYZE_SYSTEM_CHARS = 4_500;
const ANALYZE_OUTPUT_TOKENS_ESTIMATE = 1_200;
const WEEKLY_USER_CHARS_ESTIMATE = 2_500;
const WEEKLY_OUTPUT_TOKENS_ESTIMATE = 400;

/** GPT-5 / archive synthesis pilot — conservative for budget guard via analyze kind. */
const GPT55_INPUT_USD_PER_1M = 5;
const GPT55_OUTPUT_USD_PER_1M = 30;
const ARCHIVE_SYNTHESIS_SYSTEM_CHARS = 3_500;
const ARCHIVE_SYNTHESIS_PACK_CHARS_ESTIMATE = 18_000;
const ARCHIVE_SYNTHESIS_OUTPUT_TOKENS_ESTIMATE = 14_000;

function dollarsToMicro(usd: number): MicroUsd {
  return Math.max(1, Math.ceil(usd * MICRO_USD_PER_DOLLAR));
}

function charsToTokens(chars: number): number {
  return Math.ceil(chars / 4);
}

function chatCompletionMicroUsd(inputChars: number, outputTokens: number): MicroUsd {
  const inputTokens = charsToTokens(inputChars);
  const inputUsd = (inputTokens / 1_000_000) * GPT4O_MINI_INPUT_USD_PER_1M;
  const outputUsd = (outputTokens / 1_000_000) * GPT4O_MINI_OUTPUT_USD_PER_1M;
  return dollarsToMicro(inputUsd + outputUsd);
}

export interface TranscribeCostInput {
  durationSeconds?: number;
  audioBytes?: number;
  maxDurationSeconds?: number;
}

export function estimateTranscribeCost(input: TranscribeCostInput = {}): MicroUsd {
  const maxDuration = input.maxDurationSeconds ?? Number(
    process.env.VOICEMEMORY_MAX_RECORDING_SECONDS ?? "120",
  );
  let seconds = input.durationSeconds ?? NaN;
  if (!Number.isFinite(seconds) || seconds <= 0) {
    const bytes = input.audioBytes ?? MAX_AUDIO_BYTES;
    seconds = Math.min(maxDuration, Math.max(30, bytes / 16_000));
  }
  const minutes = Math.min(maxDuration, seconds) / 60;
  return dollarsToMicro(minutes * WHISPER_USD_PER_MINUTE);
}

export function estimateAnalyzeCost(transcriptChars: number): MicroUsd {
  const chars = Math.min(Math.max(0, transcriptChars), MAX_TRANSCRIPT_CHARS);
  return chatCompletionMicroUsd(ANALYZE_SYSTEM_CHARS + chars, ANALYZE_OUTPUT_TOKENS_ESTIMATE);
}

export function estimateWeeklyReflectionCost(): MicroUsd {
  return chatCompletionMicroUsd(
    ANALYZE_SYSTEM_CHARS + WEEKLY_USER_CHARS_ESTIMATE,
    WEEKLY_OUTPUT_TOKENS_ESTIMATE,
  );
}

function gpt55CompletionMicroUsd(inputChars: number, outputTokens: number): MicroUsd {
  const inputTokens = charsToTokens(inputChars);
  const inputUsd = (inputTokens / 1_000_000) * GPT55_INPUT_USD_PER_1M;
  const outputUsd = (outputTokens / 1_000_000) * GPT55_OUTPUT_USD_PER_1M;
  return dollarsToMicro(inputUsd + outputUsd);
}

export function estimateArchiveSynthesisCost(packChars?: number): MicroUsd {
  const chars = Math.min(
    Math.max(packChars ?? ARCHIVE_SYNTHESIS_PACK_CHARS_ESTIMATE, 4_000),
    80_000,
  );
  const model = process.env.VOICEMEMORY_ARCHIVE_SYNTHESIS_MODEL?.trim() ?? "";
  if (model.includes("gpt-5") || model.includes("gpt-5.5")) {
    return gpt55CompletionMicroUsd(
      ARCHIVE_SYNTHESIS_SYSTEM_CHARS + chars,
      ARCHIVE_SYNTHESIS_OUTPUT_TOKENS_ESTIMATE,
    );
  }
  return chatCompletionMicroUsd(
    ARCHIVE_SYNTHESIS_SYSTEM_CHARS + chars,
    Math.min(ARCHIVE_SYNTHESIS_OUTPUT_TOKENS_ESTIMATE, 4_000),
  );
}

export function estimateAtmosphereCost(): MicroUsd {
  return dollarsToMicro(DALLE3_STANDARD_USD_PER_IMAGE);
}

export function maxEstimateForOpenAiKind(kind: ApiUsageKind): MicroUsd {
  switch (kind) {
    case "transcribe":
      return estimateTranscribeCost({ durationSeconds: undefined, audioBytes: MAX_AUDIO_BYTES });
    case "analyze":
      return estimateAnalyzeCost(MAX_TRANSCRIPT_CHARS);
    case "atmosphere":
      return estimateAtmosphereCost();
    case "attest":
      return 0;
    default:
      return 0;
  }
}

export function estimateForOpenAiKind(
  kind: ApiUsageKind,
  input?: { transcriptChars?: number; durationSeconds?: number; audioBytes?: number },
): MicroUsd {
  switch (kind) {
    case "transcribe":
      return estimateTranscribeCost({
        durationSeconds: input?.durationSeconds,
        audioBytes: input?.audioBytes,
      });
    case "analyze":
      return estimateAnalyzeCost(input?.transcriptChars ?? MAX_TRANSCRIPT_CHARS);
    case "atmosphere":
      return estimateAtmosphereCost();
    case "attest":
      return 0;
    default:
      return 0;
  }
}

export function microUsdToUsd(micro: MicroUsd): number {
  return micro / MICRO_USD_PER_DOLLAR;
}

export function formatMicroUsd(micro: MicroUsd): string {
  return `$${microUsdToUsd(micro).toFixed(4)}`;
}

/** Guard prompt size for atmosphere — no extra product surface. */
export function atmospherePromptWithinBudget(promptLength: number): boolean {
  return promptLength > 0 && promptLength <= MAX_ATMOSPHERE_PROMPT_CHARS;
}
