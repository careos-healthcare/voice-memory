export function logLiveAudio(message: string): void {
  console.log(`ARCHIVEME_LIVE: ${message}`);
}

export function logLiveAudioCritical(context: string, error: unknown): void {
  const detail = error instanceof Error ? error.message : String(error);
  console.error(`ARCHIVEME_LIVE: critical context=${context} error=${detail}`);
}

export function logLiveAudioFallback(reason: string, error?: string): void {
  console.warn(
    `ARCHIVEME_LIVE: fallback reason=${reason}${error ? ` error=${error}` : ""}`,
  );
}
