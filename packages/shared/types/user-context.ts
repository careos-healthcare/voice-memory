/**
 * Optional user context that adjusts LLM situational awareness without
 * changing the core ArchiveInsightKind taxonomy.
 */

export const LIFE_STAGE_LENSES = [
  "default",
  "newParent",
  "careerTransition",
  "recovery",
  "griefLoss",
] as const;

export type LifeStageLens = (typeof LIFE_STAGE_LENSES)[number];

export type ActiveLifeStageLens = Exclude<LifeStageLens, "default">;

export function isLifeStageLens(value: unknown): value is LifeStageLens {
  return (
    typeof value === "string" &&
    (LIFE_STAGE_LENSES as readonly string[]).includes(value)
  );
}

export function normalizeLifeStageLens(value: unknown): LifeStageLens {
  return isLifeStageLens(value) ? value : "default";
}
