import {
  isJunkReflectionTranscript,
  isPrimarySurfacedReflection,
} from "@/lib/reflection/reflection-quality-gate";
import type { JournalEntry } from "@/types/journal";

/** Fallback when continuity would otherwise surface test/noise content. */
export const CONTINUITY_FALLBACK_LINE = "Say the next thing before it hardens.";

/** Raw transcript unsuitable for continuity or return threads. */
export function isLowQualityTranscript(text: string): boolean {
  return isJunkReflectionTranscript(text);
}

/** Quote or line shown above the mic or on thread cards. */
export function isLowQualityContinuityQuote(text: string): boolean {
  const stripped = text.replace(/^["']|["']$/g, "").trim();
  if (!stripped) return true;
  return isJunkReflectionTranscript(stripped);
}

export function gateContinuityQuote(quote: string): string | null {
  const trimmed = quote.trim();
  if (!trimmed || isLowQualityContinuityQuote(trimmed)) return null;
  return trimmed;
}

export function gateContinuityLine(line: string | null | undefined): string | null {
  if (!line?.trim()) return null;
  const trimmed = line.trim();
  if (isLowQualityContinuityQuote(trimmed)) return null;
  if (isJunkReflectionTranscript(trimmed)) return null;
  if (/\b\d+\s*[,.\s]\s*\d+\s*[,.\s]\s*\d+/.test(trimmed)) return null;
  return trimmed;
}

/** At least one reflection worth quoting before any continuity line ships. */
export function passesHardContinuityGate(entries: JournalEntry[]): boolean {
  return entries.some(isPrimarySurfacedReflection);
}

/** Pre-mic or homepage line — never surfaces test/number noise. */
export function resolveContinuityLine(line: string | null | undefined): string | null {
  const gated = gateContinuityLine(line);
  if (gated) return gated;
  return null;
}

/** When a line slot exists but content is weak, use calm fallback. */
export function resolveContinuityLineOrFallback(
  line: string | null | undefined,
  options?: { allowFallback?: boolean },
): string | null {
  const gated = resolveContinuityLine(line);
  if (gated) return gated;
  if (options?.allowFallback === false) return null;
  return CONTINUITY_FALLBACK_LINE;
}
