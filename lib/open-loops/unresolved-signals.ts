import {
  getCachedUnresolvedThread,
  hasCachedUnresolvedThreadLanguage,
  cachedUnresolvedDetectionScore,
} from "@/lib/open-loops/unresolved-cache";

export type { UnresolvedThreadSignal } from "@/lib/open-loops/unresolved-detect-core";
export { detectUnresolvedThreadUncached } from "@/lib/open-loops/unresolved-detect-core";

export function detectUnresolvedThread(
  transcript: string,
): import("@/lib/open-loops/unresolved-detect-core").UnresolvedThreadSignal | null {
  return getCachedUnresolvedThread(transcript);
}

export function hasUnresolvedThreadLanguage(transcript: string): boolean {
  return hasCachedUnresolvedThreadLanguage(transcript);
}

export function unresolvedDetectionScore(transcript: string): number {
  return cachedUnresolvedDetectionScore(transcript);
}
