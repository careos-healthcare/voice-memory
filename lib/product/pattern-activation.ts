import { BLIND_SPOT_MIN_REFLECTIONS } from "@/lib/blind-spots/blind-spot-copy";
import { PATTERN_ACTIVATION } from "@/lib/product/product-clarity-copy";
import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";

export const PATTERN_REVIEW_REFLECTION_TARGET = BLIND_SPOT_MIN_REFLECTIONS;

export interface PatternActivationProgress {
  current: number;
  target: number;
  line: string;
  readyForPatternReview: boolean;
  blindSpotsHref: string;
  discoverHref: string;
}

export function countPatternActivationReflections(): number {
  return countCompletedReflections();
}

export function buildPatternActivationProgress(
  reflectionCount?: number,
): PatternActivationProgress | null {
  const current = reflectionCount ?? countPatternActivationReflections();
  const target = PATTERN_REVIEW_REFLECTION_TARGET;

  if (current < 1) return null;

  const readyForPatternReview = current >= target;

  return {
    current,
    target,
    line: readyForPatternReview
      ? PATTERN_ACTIVATION.readyLead
      : PATTERN_ACTIVATION.progressTemplate(current, target),
    readyForPatternReview,
    blindSpotsHref: "/blind-spots",
    discoverHref: "/discover",
  };
}

export function shouldShowPatternActivationProgress(reflectionCount?: number): boolean {
  const count = reflectionCount ?? countPatternActivationReflections();
  return count >= 1 && count <= PATTERN_REVIEW_REFLECTION_TARGET + 12;
}
