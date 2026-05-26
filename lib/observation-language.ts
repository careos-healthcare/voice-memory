import { MEMORY_LANGUAGE } from "@/lib/memory-language";
import type { Reflection } from "@/types/journal";

/** Primary observation line for UI — never falls back to legacy therapy fields. */
export function getPrimaryObservation(reflection: Reflection): string | null {
  if (reflection.concreteObservation?.trim()) {
    return reflection.concreteObservation.trim();
  }
  if (reflection.tensionOrContradiction?.trim()) {
    return reflection.tensionOrContradiction.trim();
  }
  if (reflection.repeatedSignal?.trim()) {
    const signal = reflection.repeatedSignal.trim();
    if (!signal.toLowerCase().startsWith("nothing repeated")) return signal;
  }
  if (reflection.exactLanguagePattern?.trim()) {
    return `"${reflection.exactLanguagePattern.trim()}"`;
  }
  const obs = reflection.patternObservations?.find((o) => o.trim());
  if (obs) return obs.trim();
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
    rows.push({
      key: "exact",
      label: MEMORY_LANGUAGE.yourOwnWords,
      detail: `"${reflection.exactLanguagePattern.trim()}"`,
    });
  }
  if (reflection.concreteObservation?.trim()) {
    rows.push({
      key: "concrete",
      label: MEMORY_LANGUAGE.whatStoodOut,
      detail: reflection.concreteObservation.trim(),
    });
  }
  if (reflection.tensionOrContradiction?.trim()) {
    rows.push({
      key: "tension",
      label: MEMORY_LANGUAGE.twoTruths,
      detail: reflection.tensionOrContradiction.trim(),
    });
  }
  if (reflection.repeatedSignal?.trim()) {
    const signal = reflection.repeatedSignal.trim();
    if (!signal.toLowerCase().startsWith("nothing repeated")) {
      rows.push({
        key: "repeat",
        label: MEMORY_LANGUAGE.youSaidBefore.replace(/\.$/, ""),
        detail: signal,
      });
    }
  }
  if (reflection.avoidedOrVagueArea?.trim()) {
    rows.push({
      key: "vague",
      label: MEMORY_LANGUAGE.leftIndirect.replace(/\.$/, ""),
      detail: reflection.avoidedOrVagueArea.trim(),
    });
  }
  if (reflection.nextSmallAction?.trim()) {
    rows.push({
      key: "action",
      label: "Next step in your words",
      detail: reflection.nextSmallAction.trim(),
    });
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
