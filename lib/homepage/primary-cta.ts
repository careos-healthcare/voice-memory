/** Deterministic primary recorder CTA ownership on the homepage. Lower number wins. */
export const PRIMARY_CTA_PRIORITY = [
  "onboarding",
  "recorder",
  "retry",
  "processing",
] as const;

export type PrimaryCtaId = (typeof PRIMARY_CTA_PRIORITY)[number];

export const PRIMARY_CTA_LABELS: Record<PrimaryCtaId, string> = {
  onboarding: "Record a reflection",
  recorder: "Start reflection",
  retry: "Try again",
  processing: "Processing",
};

export function resolvePrimaryCtaWinner(
  registry: Partial<Record<PrimaryCtaId, boolean>>,
): PrimaryCtaId | null {
  for (const id of PRIMARY_CTA_PRIORITY) {
    if (registry[id]) return id;
  }
  return null;
}
