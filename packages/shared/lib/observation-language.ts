import { MEMORY_LANGUAGE } from "@/lib/memory-language";
import { sanitizeUserFacingObservation } from "@/lib/product/human-continuity-ui";
import type { Reflection } from "@/types/journal";

/** Primary observation line for UI — never falls back to legacy therapy fields. */
export function getPrimaryObservation(reflection: Reflection): string | null {
  if (reflection.concreteObservation?.trim()) {
    return sanitizeUserFacingObservation(reflection.concreteObservation) ?? null;
  }
  if (reflection.tensionOrContradiction?.trim()) {
    return sanitizeUserFacingObservation(reflection.tensionOrContradiction);
  }
  if (reflection.repeatedSignal?.trim()) {
    const signal = reflection.repeatedSignal.trim();
    if (!signal.toLowerCase().startsWith("nothing repeated")) {
      return sanitizeUserFacingObservation(signal);
    }
  }
  if (reflection.exactLanguagePattern?.trim()) {
    const quote = reflection.exactLanguagePattern.trim();
    return sanitizeUserFacingObservation(`"${quote}"`) ?? `"${quote}"`;
  }
  const obs = reflection.patternObservations?.find((o) => o.trim());
  if (obs) return sanitizeUserFacingObservation(obs);
  return null;
}

/** Structured read-back fields in mirror priority order. */
export function getStructuredAnalysis(reflection: Reflection): Array<{
  key: string;
  label: string;
  detail: string;
}> {
  const rows: Array<{ key: string; label: string; detail: string }> = [];

  if (reflection.exactLanguagePattern?.trim()) {
    const quote = `"${reflection.exactLanguagePattern.trim()}"`;
    const detail = sanitizeUserFacingObservation(quote) ?? quote;
    rows.push({
      key: "exact",
      label: MEMORY_LANGUAGE.yourOwnWords,
      detail,
    });
  }
  if (reflection.concreteObservation?.trim()) {
    const detail = sanitizeUserFacingObservation(reflection.concreteObservation);
    if (detail) {
      rows.push({
        key: "concrete",
        label: MEMORY_LANGUAGE.whatStoodOut,
        detail,
      });
    }
  }
  if (reflection.tensionOrContradiction?.trim()) {
    const detail = sanitizeUserFacingObservation(reflection.tensionOrContradiction);
    if (detail) {
      rows.push({
        key: "tension",
        label: MEMORY_LANGUAGE.twoTruths,
        detail,
      });
    }
  }
  if (reflection.repeatedSignal?.trim()) {
    const signal = reflection.repeatedSignal.trim();
    if (!signal.toLowerCase().startsWith("nothing repeated")) {
      const detail = sanitizeUserFacingObservation(signal);
      if (detail) {
        rows.push({
          key: "repeat",
          label: MEMORY_LANGUAGE.youSaidBefore.replace(/\.$/, ""),
          detail,
        });
      }
    }
  }
  if (reflection.avoidedOrVagueArea?.trim()) {
    const detail = sanitizeUserFacingObservation(reflection.avoidedOrVagueArea);
    if (detail) {
      rows.push({
        key: "vague",
        label: MEMORY_LANGUAGE.leftIndirect.replace(/\.$/, ""),
        detail,
      });
    }
  }

  return rows;
}

export function buildPatternObservationsFromAnalysis(
  reflection: Pick<
    Reflection,
    | "exactLanguagePattern"
    | "concreteObservation"
    | "tensionOrContradiction"
    | "repeatedSignal"
    | "avoidedOrVagueArea"
    | "nextSmallAction"
  >,
): string[] {
  return getStructuredAnalysis(reflection as Reflection)
    .map((row) => row.detail)
    .slice(0, 5);
}
