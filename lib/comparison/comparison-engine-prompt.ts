/**
 * System prompt and guardrails for ArchiveMe moment-to-moment comparisons.
 * Mirrors the mobile ComparisonEnginePrompt contract.
 */

export const COMPARISON_THIN_EVIDENCE_DEFAULT =
  "ArchiveMe needs more moments to be sure.";

export const COMPARISON_CONFIDENCE_LABELS = [
  "Early signal",
  "Possible repeat",
  "Clear repeat",
  "Still current",
  "Fading",
  "Changed",
  "Softened",
  "Corrected",
  "Not enough evidence",
] as const;

export type ComparisonConfidenceLabel = (typeof COMPARISON_CONFIDENCE_LABELS)[number];

/** Enum keys aligned with mobile ComparisonConfidenceLabel. */
export const COMPARISON_CONFIDENCE_LABEL_KEYS = [
  "earlySignal",
  "possibleRepeat",
  "clearRepeat",
  "stillCurrent",
  "fading",
  "changed",
  "softened",
  "corrected",
  "notEnoughEvidence",
] as const;

export type ComparisonConfidenceLabelKey =
  (typeof COMPARISON_CONFIDENCE_LABEL_KEYS)[number];

export const COMPARISON_BANNED_PHRASE_PREFIXES = [
  "you always",
  "this means",
  "your pattern is",
  "you have a deep fear of",
  "here is my diagnosis",
] as const;

export const COMPARISON_BANNED_PHRASE_SUBSTRINGS = [
  "you always ",
  "this means ",
  "your pattern is ",
  "you have a deep fear of ",
  "here is my diagnosis",
  "to fix this you should",
] as const;

export const COMPARISON_ENGINE_SYSTEM_PROMPT = `You are the private comparison engine for ArchiveMe. Compare a new saved moment with previous saved moments using evidence only — never therapy, diagnosis, or personality claims.

NEVER USE OR START WITH:
- "You always..."
- "This means..."
- "Your pattern is..."
- "You have a deep fear of..."
- "Here is my diagnosis..."

Use ONLY the user's direct saved words as evidence. Never invent quotes or paraphrase without marking uncertainty.

If confidence or evidence is low, you MUST output this exact caution in Connection or What Changed:
"${COMPARISON_THIN_EVIDENCE_DEFAULT}"

You MUST classify the relationship using exactly ONE of these labels (display label in parentheses):
- earlySignal (Early signal)
- possibleRepeat (Possible repeat)
- clearRepeat (Clear repeat)
- stillCurrent (Still current)
- fading (Fading)
- changed (Changed)
- softened (Softened)
- corrected (Corrected)
- notEnoughEvidence (Not enough evidence)

OUTPUT FORMAT — your response must strictly follow this layout:
---
Label: [Insert exactly one allowed display label from above]
Connection: [1-2 cautious sentences. Use "This may connect to..." when unsure.]
Evidence:
- Past: "[Exact quote from the past saved moment — required unless Label is Not enough evidence]"
- Present: "[Exact quote from the current saved moment — required unless Label is Not enough evidence]"
What Changed: [Describe the precise difference in saved words, or "${COMPARISON_THIN_EVIDENCE_DEFAULT}"]
---

Rules:
- Past and Present must be verbatim substrings from the supplied moments (except Not enough evidence).
- Never claim certainty. Use observation language only.
- Do not offer advice, fixes, or clinical interpretation.`;

export function violatesComparisonBannedPhrase(text: string): boolean {
  const lower = text.trim().toLowerCase();
  if (!lower) return false;
  for (const prefix of COMPARISON_BANNED_PHRASE_PREFIXES) {
    if (lower.startsWith(prefix)) return true;
  }
  for (const phrase of COMPARISON_BANNED_PHRASE_SUBSTRINGS) {
    if (lower.includes(phrase)) return true;
  }
  return false;
}

export function allowsMissingComparisonEvidenceQuotes(
  label: ComparisonConfidenceLabel,
): boolean {
  return label === "Not enough evidence";
}

export interface ComparisonEngineOutput {
  confidenceLabel: ComparisonConfidenceLabel;
  whatAppearsRepeated: string;
  connectedMomentDayTime: string;
  connectedEntryId?: string;
  whatChanged?: string;
  thinEvidencePhrase?: string;
  /** Verbatim excerpt from the prior saved moment. */
  pastQuote: string;
  /** Verbatim excerpt from the current saved moment. */
  presentQuote: string;
}

export function comparisonOutputHasRequiredEvidenceQuotes(
  output: ComparisonEngineOutput,
): boolean {
  if (allowsMissingComparisonEvidenceQuotes(output.confidenceLabel)) {
    return true;
  }
  return (
    output.pastQuote.trim().length > 0 && output.presentQuote.trim().length > 0
  );
}

export function formatComparisonStructuredSummary(
  output: ComparisonEngineOutput,
): string {
  const lines = [
    `Label: ${output.confidenceLabel}`,
    `Connection: ${output.whatAppearsRepeated}`,
    `Connects to: ${output.connectedMomentDayTime}`,
  ];
  if (output.pastQuote.trim() || output.presentQuote.trim()) {
    lines.push("Evidence:");
    if (output.pastQuote.trim()) {
      lines.push(`- Past: "${output.pastQuote.trim()}"`);
    }
    if (output.presentQuote.trim()) {
      lines.push(`- Present: "${output.presentQuote.trim()}"`);
    }
  }
  const changed = output.whatChanged?.trim();
  if (changed) lines.push(`What changed: ${changed}`);
  const caution = output.thinEvidencePhrase?.trim();
  if (caution) lines.push(caution);
  return lines.join("\n");
}
