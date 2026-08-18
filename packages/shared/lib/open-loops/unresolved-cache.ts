import { detectUnresolvedThreadUncached } from "@/lib/open-loops/unresolved-detect-core";
import type { UnresolvedThreadSignal } from "@/lib/open-loops/unresolved-detect-core";
import {
  recordUnresolvedDetectionInvocation,
  transcriptCacheKey,
} from "@/lib/open-loops/open-loop-performance";

const cache = new Map<string, UnresolvedThreadSignal | null>();

export function getCachedUnresolvedThread(
  transcript: string,
): UnresolvedThreadSignal | null {
  const text = transcript.trim();
  if (text.length < 12) return null;

  const key = transcriptCacheKey(text);
  if (cache.has(key)) {
    return cache.get(key) ?? null;
  }

  recordUnresolvedDetectionInvocation();
  const signal = detectUnresolvedThreadUncached(text);
  cache.set(key, signal);
  return signal;
}

export function hasCachedUnresolvedThreadLanguage(transcript: string): boolean {
  return getCachedUnresolvedThread(transcript) !== null;
}

export function cachedUnresolvedDetectionScore(transcript: string): number {
  const signal = getCachedUnresolvedThread(transcript);
  return signal?.matchedLabels.length ?? 0;
}

export function resetUnresolvedDetectionCache(): void {
  cache.clear();
}

export function unresolvedDetectionCacheSize(): number {
  return cache.size;
}
