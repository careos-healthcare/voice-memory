/** Builds the Gemini Live Bidi WebSocket URL — caller must supply the server-held API key. */
export function geminiLiveWebSocketUrl(apiKey: string): string {
  const encodedKey = encodeURIComponent(apiKey.trim());
  return (
    "wss://generativelanguage.googleapis.com/ws/" +
    "google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent" +
    `?key=${encodedKey}`
  );
}
