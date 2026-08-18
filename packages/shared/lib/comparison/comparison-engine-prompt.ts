/**
 * System prompt and guardrails for ArchiveMe moment-to-moment comparisons.
 * Mirrors the mobile ComparisonEnginePrompt contract.
 */

export const COMPARISON_ENGINE_SYSTEM_PROMPT = `You compare saved ArchiveMe moments using evidence only — never therapy, diagnosis, or personality claims.

NEVER USE OR START WITH:
- "You always..."
- "This means..."
- "Your pattern is..."
- "You have a deep fear of..."

CONFIDENCE LABEL — use exactly one of:
Early signal, Possible repeat, Clear repeat, Still current, Fading, Changed, Softened, Corrected, Not enough evidence

OUTPUT — answer these elements in order:
1. What appears to have repeated (cautious, grounded in saved words)
2. Which saved moment it connects to (by day and time)
3. What changed (if known; omit when unknown)
4. A cautious phrase if evidence is thin (e.g. "ArchiveMe needs more moments to be sure.")

Use observation language. Quote the user's words when possible. Never claim certainty.`;

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

export const COMPARISON_THIN_EVIDENCE_DEFAULT =
  "ArchiveMe needs more moments to be sure.";

export const COMPARISON_BANNED_PHRASE_PREFIXES = [
  "you always",
  "this means",
  "your pattern is",
  "you have a deep fear of",
] as const;

export function violatesComparisonBannedPhrase(text: string): boolean {
  const lower = text.trim().toLowerCase();
  if (!lower) return false;
  return COMPARISON_BANNED_PHRASE_PREFIXES.some(
    (prefix) => lower.startsWith(prefix) || lower.includes(`${prefix} `),
  );
}

export interface ComparisonEngineOutput {
  confidenceLabel: ComparisonConfidenceLabel;
  whatAppearsRepeated: string;
  connectedMomentDayTime: string;
  connectedEntryId?: string;
  whatChanged?: string;
  thinEvidencePhrase?: string;
}

export function formatComparisonStructuredSummary(
  output: ComparisonEngineOutput,
): string {
  const lines = [
    `Confidence: ${output.confidenceLabel}`,
    `What appears to have repeated: ${output.whatAppearsRepeated}`,
    `Connects to: ${output.connectedMomentDayTime}`,
  ];
  const changed = output.whatChanged?.trim();
  if (changed) lines.push(`What changed: ${changed}`);
  const caution = output.thinEvidencePhrase?.trim();
  if (caution) lines.push(caution);
  return lines.join("\n");
}
