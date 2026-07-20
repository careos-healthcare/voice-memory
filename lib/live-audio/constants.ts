/** PCM input for Gemini Live — 16-bit LE @ 16 kHz. */
export const LIVE_INPUT_AUDIO_MIME = "audio/pcm;rate=16000";

/** PCM output from Gemini Live — 16-bit LE @ 24 kHz. */
export const LIVE_OUTPUT_AUDIO_MIME = "audio/pcm;rate=24000";

export const DEFAULT_LIVE_VOICE_NAME = "Aoede";

/** Short-lived proxy session ticket TTL. */
export const LIVE_SESSION_TTL_MS = 1000 * 60 * 15;

/** Offline vault recovery remains eligible after the live WS session ends. */
export const VAULT_RECOVERY_TTL_MS = 1000 * 60 * 60 * 24 * 7;

/** Query parameter used to authenticate with the backend live-audio proxy. */
export const LIVE_SESSION_TOKEN_QUERY_PARAM = "sessionToken";

/** Relative WebSocket path clients connect to on this backend. */
export const LIVE_AUDIO_PROXY_WS_PATH = "/api/live-audio/ws";
