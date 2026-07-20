import { DEFAULT_LIVE_VOICE_NAME } from "@/lib/live-audio/constants";
import type { LiveSetupClientMessage } from "@/lib/live-audio/protocol/types";

export interface BuildLiveSetupOptions {
  modelId?: string;
  voiceName?: string;
}

export function normalizeLiveModelResource(modelId: string): string {
  const trimmed = modelId.trim();
  return trimmed.startsWith("models/") ? trimmed : `models/${trimmed}`;
}

/** First client frame for a Gemini Live Bidi session. */
export function buildLiveSetupMessage(
  options: BuildLiveSetupOptions = {},
): LiveSetupClientMessage {
  const modelId =
    options.modelId ??
    process.env.VOICEMEMORY_GEMINI_LIVE_MODEL ??
    "gemini-2.5-flash-native-audio-preview-12-2025";

  return {
    setup: {
      model: normalizeLiveModelResource(modelId),
      generationConfig: {
        responseModalities: ["AUDIO"],
        speechConfig: {
          voiceConfig: {
            prebuiltVoiceConfig: {
              voiceName: options.voiceName ?? DEFAULT_LIVE_VOICE_NAME,
            },
          },
        },
      },
    },
  };
}
