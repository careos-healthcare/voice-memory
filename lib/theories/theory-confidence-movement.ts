import { FORBIDDEN_THEORY_OUTPUT } from "@/lib/theories/theory-copy";

export const PERSONAL_THEORY_COPY = {
  evidenceLabel: "Evidence",
  confidenceLabel: "Confidence",
  statusLabel: "Status",
  currentConfidenceLabel: "Current confidence",
  lastConfidenceLabel: "Last confidence",
  archiveMoreConfident:
    "Your archive has become more confident — still a working theory, not a verdict.",
  archiveLessConfident:
    "Your archive has become less confident — the theory may need more or different evidence.",
  archiveUnchanged: "Confidence unchanged since your last visit.",
  supportingEvidenceLine: "New evidence appeared in recent reflections.",
  contradictingEvidenceLine: "Recent entries contradicted this theory.",
  mixedEvidenceLine:
    "Supporting and contradicting reflections both appear — still under review.",
} as const;

const CERTAINTY_RE =
  /\b(certainly|definitely|proven|guaranteed|always means|will always|without doubt|confirmed diagnosis)\b/i;

export interface ConfidenceMovementInput {
  currentConfidence: number;
  previousConfidence?: number;
  delta?: number;
  lifeAreaHint?: string;
  contradictingCount?: number;
  supportingCount?: number;
}

export interface ConfidenceMovementView {
  currentConfidence: number;
  previousConfidence?: number;
  delta: number;
  deltaLabel: string;
  previousLabel?: string;
  explanation: string;
  archiveRead?: string;
}

export function clampConfidence(value: number): number {
  return Math.max(0, Math.min(100, Math.round(value)));
}

export function formatConfidenceDelta(delta: number): string {
  if (delta === 0) return "No change";
  return delta > 0 ? `+${delta} confidence` : `${delta} confidence`;
}

export function explainConfidenceMovement(
  input: ConfidenceMovementInput,
): string {
  const delta =
    input.delta ??
    (input.previousConfidence !== undefined
      ? input.currentConfidence - input.previousConfidence
      : 0);

  if (delta > 0) {
    const area = input.lifeAreaHint?.trim();
    if (area) {
      return `New evidence appeared in ${area} reflections.`;
    }
    return PERSONAL_THEORY_COPY.supportingEvidenceLine;
  }
  if (delta < 0) {
    return PERSONAL_THEORY_COPY.contradictingEvidenceLine;
  }
  if (
    (input.contradictingCount ?? 0) > 0 &&
    (input.supportingCount ?? 0) > 0
  ) {
    return PERSONAL_THEORY_COPY.mixedEvidenceLine;
  }
  return PERSONAL_THEORY_COPY.archiveUnchanged;
}

export function formatConfidenceMovement(
  input: ConfidenceMovementInput,
): ConfidenceMovementView {
  const currentConfidence = clampConfidence(input.currentConfidence);
  const previousConfidence =
    input.previousConfidence !== undefined
      ? clampConfidence(input.previousConfidence)
      : undefined;
  const delta =
    input.delta ??
    (previousConfidence !== undefined
      ? currentConfidence - previousConfidence
      : 0);

  const explanation = explainConfidenceMovement({
    ...input,
    currentConfidence,
    previousConfidence,
    delta,
  });
  assertNoCertaintyLanguage(explanation);

  let archiveRead: string | undefined;
  if (delta > 0) archiveRead = PERSONAL_THEORY_COPY.archiveMoreConfident;
  else if (delta < 0) archiveRead = PERSONAL_THEORY_COPY.archiveLessConfident;

  return {
    currentConfidence,
    previousConfidence,
    delta,
    deltaLabel: formatConfidenceDelta(delta),
    previousLabel:
      previousConfidence !== undefined
        ? `up from ${previousConfidence}%`
        : undefined,
    explanation,
    archiveRead,
  };
}

export function assertNoCertaintyLanguage(text: string): void {
  if (CERTAINTY_RE.test(text) || FORBIDDEN_THEORY_OUTPUT.test(text)) {
    throw new Error(`Personal theory copy failed restraint: ${text}`);
  }
}
