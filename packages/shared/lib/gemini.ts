import "server-only";

/** Default Live native-audio model for Google AI Studio (Developer API). */
export const GEMINI_LIVE_MODEL_ID =
  process.env.VOICEMEMORY_GEMINI_LIVE_MODEL ??
  "gemini-2.5-flash-native-audio-preview-12-2025";

export { geminiLiveWebSocketUrl } from "@/lib/live-audio/upstream-url";

export function isGeminiKillSwitchActive(): boolean {
  return process.env.VOICEMEMORY_GEMINI_KILL_SWITCH === "true";
}

export function getGeminiApiKey(): string {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not configured");
  }
  return apiKey;
}

export function isGeminiConfigured(): boolean {
  return Boolean(process.env.GEMINI_API_KEY?.trim());
}
