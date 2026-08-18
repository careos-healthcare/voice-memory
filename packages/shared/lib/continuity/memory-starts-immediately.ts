import {
  gateContinuityLine,
  resolveContinuityLine,
} from "@/lib/continuity/continuity-quality-gate";
import { pickEarlyResurfacingMagicLine } from "@/lib/continuity/early-resurfacing-magic";
import { RECOGNITION_COPY } from "@/lib/product/recognition-copy";
import { isPrimarySurfacedReflection } from "@/lib/reflection/reflection-quality-gate";
import type { JournalEntry } from "@/types/journal";

export const FIRST_REFLECTION_SAVED_LINE = RECOGNITION_COPY.firstSave;

export const NOTHING_RETURNED_YET_LINE = RECOGNITION_COPY.nothingReturned;

export function countQualityReflections(entries: JournalEntry[]): number {
  return entries.filter(isPrimarySurfacedReflection).length;
}

/** Post-save — honest tiered acknowledgment, never fabricated return. */
export function postSaveAcknowledgmentLine(entries: JournalEntry[]): string {
  const count = countQualityReflections(entries);
  if (count <= 1) return FIRST_REFLECTION_SAVED_LINE;
  return "Saved.";
}

/** Single pre-mic line — quote-led magic, calm empty, or nothing. No generic fallbacks. */
export function resolveEarlyPreMicLine(entries: JournalEntry[]): string | null {
  const count = countQualityReflections(entries);
  if (count < 2) return null;

  const magic = pickEarlyResurfacingMagicLine(entries);
  if (magic) {
    const gated = gateContinuityLine(magic);
    if (gated) return gated;
  }

  if (count >= 2) {
    return gateContinuityLine(NOTHING_RETURNED_YET_LINE) ?? NOTHING_RETURNED_YET_LINE;
  }

  return null;
}

/** Homepage / recorder — explicit line first, then early loop. */
export function resolveSurfacedPreMicLine(
  explicitLine: string | null | undefined,
  entries: JournalEntry[],
): string | null {
  const gatedExplicit = resolveContinuityLine(explicitLine);
  if (gatedExplicit) return gatedExplicit;
  return resolveEarlyPreMicLine(entries);
}
