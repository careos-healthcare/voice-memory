import type { Reflection } from "@/types/journal";

/** Normalize reflections loaded from localStorage (legacy entries may omit new fields). */
export function normalizeReflection(
  raw: Partial<Reflection> & Pick<Reflection, "mood" | "emotionalIntensity">,
): Reflection {
  const themes = Array.isArray(raw.recurringThemes)
    ? raw.recurringThemes.filter((t): t is string => typeof t === "string")
    : [];

  const intensity = Number(raw.emotionalIntensity);

  return {
    mood: String(raw.mood ?? "").trim(),
    emotionalIntensity: Math.min(
      10,
      Math.max(1, Number.isFinite(intensity) ? Math.round(intensity) : 5),
    ),
    recurringThemes: themes.slice(0, 4),
    hiddenConcern: String(raw.hiddenConcern ?? "").trim(),
    positiveSignal: String(raw.positiveSignal ?? "").trim(),
    recommendation: String(raw.recommendation ?? "").trim(),
    exactLanguagePattern: optionalString(raw.exactLanguagePattern),
    concreteObservation: optionalString(raw.concreteObservation),
    repeatedSignal: optionalString(raw.repeatedSignal),
    nextSmallAction: optionalString(raw.nextSmallAction),
  };
}

function optionalString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

export interface SpecificReflectionView {
  exactLanguagePattern: string | null;
  concreteObservation: string;
  repeatedSignal: string | null;
  nextSmallAction: string;
  isLegacyFormat: boolean;
}

export function getSpecificReflectionView(
  reflection: Reflection,
): SpecificReflectionView {
  const hasNew =
    Boolean(reflection.exactLanguagePattern) ||
    Boolean(reflection.concreteObservation) ||
    Boolean(reflection.repeatedSignal) ||
    Boolean(reflection.nextSmallAction);

  return {
    exactLanguagePattern: reflection.exactLanguagePattern ?? null,
    concreteObservation:
      reflection.concreteObservation?.trim() ||
      reflection.hiddenConcern.trim() ||
      "No concrete observation saved for this entry.",
    repeatedSignal:
      reflection.repeatedSignal?.trim() ||
      (reflection.recurringThemes.length > 0
        ? `Themes noted: ${reflection.recurringThemes.join(", ")}`
        : null),
    nextSmallAction:
      reflection.nextSmallAction?.trim() ||
      reflection.recommendation.trim() ||
      "No next step saved.",
    isLegacyFormat: !hasNew,
  };
}

export function hasEnhancedReflection(reflection: Reflection): boolean {
  return Boolean(
    reflection.exactLanguagePattern ||
      reflection.concreteObservation ||
      reflection.repeatedSignal ||
      reflection.nextSmallAction,
  );
}
