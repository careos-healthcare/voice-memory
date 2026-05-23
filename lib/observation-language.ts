import type { Reflection } from "@/types/journal";

/** Primary observation line for UI — never falls back to legacy therapy fields. */
export function getPrimaryObservation(reflection: Reflection): string | null {
  const obs = reflection.patternObservations?.find((o) => o.trim());
  if (obs) return obs.trim();
  if (reflection.concreteObservation?.trim()) return reflection.concreteObservation.trim();
  if (reflection.repeatedSignal?.trim()) {
    const signal = reflection.repeatedSignal.trim();
    if (!signal.toLowerCase().startsWith("no clear repeat")) return signal;
  }
  if (reflection.exactLanguagePattern?.trim()) {
    return `You said: "${reflection.exactLanguagePattern.trim()}"`;
  }
  return null;
}

export function getEntryPreviewLine(reflection: Reflection): string {
  return getPrimaryObservation(reflection) ?? "Voice reflection";
}
